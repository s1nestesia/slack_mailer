require_relative 'slack_mailer/configuration'
require_relative 'slack_mailer/delivery_worker'
require 'slack-notifier'
require 'erb'

module Slack
  class Mailer

    class << self
      def method_missing(method, *args)
        self.new.send(method, *args)
      end

      def send_message(channel = '', name = '', message = '')
        return if channel.empty? || name.empty? || message.empty?
        Slack::Mailer::DeliveryWorker.perform_async(name: name, message: message, channel: channel)
      end

      def send_direct_message(channel = '', name = '', message = '')
        return if channel.empty? || name.empty? || message.empty?
        Slack::Notifier.new(Slack::Mailer::Configuration.slack_hook_url, username: name, channel: channel, link_names: 1)
          .ping(message)
      end
    end

    def mail(to: nil, template: nil, bot_name: "#{self.class.name}##{template}", use_sidekiq: true)
      channel = "##{to}"
      instance_variables = self.instance_variables.map { |instance_variable|
        { instance_variable => self.instance_variable_get(instance_variable) }
      }.reduce(:merge)
      message = collect_message(template, instance_variables)
      method = use_sidekiq ? :send_message : :send_direct_message
      self.class.send(method, channel, bot_name, message)
    end

    def collect_message(template, instance_variables)
      template = "#{template}.#{Slack::Mailer::Configuration.config.templates_type}"
      template << '.erb' if Slack::Mailer::Configuration.config.erb_in_templates

      ERB.new(
        File.read("#{Slack::Mailer::Configuration.config.templates_path}/#{self.class.name.underscore}/#{template}")
      ).result(binding)
    end

  end
end
