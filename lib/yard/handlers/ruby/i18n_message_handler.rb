# Handles +_+ statements in modules/classes
class YARD::Handlers::Ruby::I18NMessageHandler < YARD::Handlers::Ruby::Base
  handles method_call

  process do
    statement.traverse do |node|
      next unless node.call?
      next unless /\A(?:N_|s_|_)\z/ =~ node.method_name(true)
      params, block_param = node.parameters
      next if block_param
      next if params.size != 1
      message_node = params.jump(:tstring_content)
      next if message_node.nil?
      namespace.attributes[:i18n] ||= {}
      namespace.attributes[:i18n][:messages] ||= []
      namespace.attributes[:i18n][:messages] << {
        :line => message_node.line_range.begin,
        :file => message_node.file,
        :message => message_node.source,
      }
    end
  end
end
