require 'etc'
require 'net/https'
require 'uri'
require 'json'

module CapGun
  class Presenter
    DEFAULT_SENDER = %("CapGun" <cap_gun@example.com>)
    DEFAULT_EMAIL_PREFIX = "[DEPLOY]"
    
    attr_accessor :capistrano
    
    def initialize(capistrano)
      self.capistrano = capistrano
    end

    def recipients
      capistrano[:cap_gun_email_envelope][:recipients]
    end

    def email_prefix
      capistrano[:cap_gun_email_envelope][:email_prefix] || DEFAULT_EMAIL_PREFIX
    end

    def from
      capistrano[:cap_gun_email_envelope][:from] || DEFAULT_SENDER
    end
    
    def current_user
      Etc.getlogin
    end

    def summary
      %[#{capistrano[:application]} was #{deployed_to} by #{current_user} at #{release_time}.]
    end

    def deployed_to
      return "deployed to #{capistrano[:rails_env]}" if capistrano[:rails_env]
      "deployed"
    end

    def branch
      "Branch: #{capistrano[:branch]}" unless capistrano[:branch].nil? || capistrano[:branch].empty?
    end

    def scm_details
      return unless [:git,:subversion].include? capistrano[:scm].to_sym
      <<-EOL
#{branch}
#{scm_log}
      EOL
      rescue
        nil
    end

    def scm_log
      "\nCommits since last release\n====================\n#{scm_log_messages}"
    end

    def scm_log_messages
      messages = case capistrano[:scm].to_sym
        when :git
          if capistrano[:github_token]
            github_log_messages
          else
            `git log #{previous_revision}..#{capistrano[:current_revision]} --pretty=format:%h:%s`
          end
        when :subversion
          `svn log -r #{previous_revision.to_i+1}:#{capistrano[:current_revision]}`
        else
          "N/A"
      end
      exit_code.success? ? messages : "N/A"
    end

    def github_log_messages
      token = capistrano[:github_token]
      repo  = capistrano[:repository].match(/github\.com.(\w+\/\w+)/)[1]
      base  = previous_revision
      head  = capistrano[:current_revision]

      uri = URI.parse("https://api.github.com/repos/#{repo}/compare/#{base}...#{head}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "token #{token}"
      response = http.request(request)

      if response.code.to_i == 200
        messages = JSON.parse(response.body)["commits"].map do |c|
          sha = c["sha"][0...7]
          message = c["commit"]["message"].split("\n").first
          "#{sha}:#{message}"
        end
        messages.join("\n")
      else
        "N/A"
      end
    end

    def exit_code
      $?
    end

    # Gives you a prettier date/time for output from the standard Capistrano timestamped release directory.
    # This assumes Capistrano uses UTC for its date/timestamped directories, and converts to the local
    # machine timezone.
    def humanize_release_time(path)
      return unless path
      match = path.match(/(\d+)$/)
      return unless match
      local = convert_from_utc(match[1])
      local.strftime("%B #{local.day.ordinalize}, %Y %l:%M %p #{local_timezone}").gsub(/\s+/, ' ').strip
    end
    
    # Use some DateTime magicrey to convert UTC to the current time zone
    # When the whole world is on Rails 2.1 (and therefore new ActiveSupport) we can use the magic timezone support there.
    def convert_from_utc(timestamp)
      # we know Capistrano release timestamps are UTC, but Ruby doesn't, so make it explicit
      utc_time = timestamp << "UTC" 
      datetime = DateTime.parse(utc_time)
      datetime.new_offset(local_datetime_zone_offset)
    end
    
    def local_datetime_zone_offset
      @local_datetime_zone_offset ||= DateTime.now.offset
    end
    
    def local_timezone
      @current_timezone ||= Time.now.zone
    end
    
    def release_time
      humanize_release_time(capistrano[:current_release])
    end
    
    def previous_revision
      capistrano.fetch(:previous_revision, "n/a")
    end
    
    def previous_release_time 
      humanize_release_time(capistrano[:previous_release])
    end

    def subject
      "#{email_prefix} #{capistrano[:application]} #{deployed_to}"
    end
    
    def comment
      "Comment: #{capistrano[:comment]}.\n" if capistrano[:comment]
    end

    def body
<<-EOL
#{summary}
#{comment}
Deployment details
==================
Release: #{capistrano[:current_release]}
Release Time: #{release_time}
Release Revision: #{capistrano[:current_revision]}

Previous Release: #{capistrano[:previous_release]}
Previous Release Time: #{previous_release_time}
Previous Release Revision: #{previous_revision}

Repository: #{capistrano[:repository]}
Deploy path: #{capistrano[:deploy_to]}
Domain: #{capistrano[:domain]}
#{scm_details}
EOL
    end

  end
end
