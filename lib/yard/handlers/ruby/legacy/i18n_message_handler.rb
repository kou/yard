# (see Ruby::I18NMessageHandler)
class YARD::Handlers::Ruby::Legacy::I18NMessageHandler < YARD::Handlers::Ruby::Legacy::Base
  handles TkIDENTIFIER
  handles TkCONSTANT

  process do
    method_name = statement.tokens.first.text
    case method_name
    when /\A(?:N_|s_|_)\z/
      arguments = tokval_list(statement.tokens[1..-1], :all)
      return if arguments.size != 1
      argument = arguments.first
      return unless argument.is_a?(String)
      namespace.attributes[:i18n] ||= {}
      namespace.attributes[:i18n][:messages] ||= []
      namespace.attributes[:i18n][:messages] << {
        :line => statement.tokens[1].line_no,
        :file => parser.file,
        :message => argument,
      }
    else
      tokval_list(statement.tokens[1..-1], :all).each do |arguments_text|
        push_state do
          arguments = statement_list(arguments_text)
          arguments.each do |argument|
            case argument.tokens.first
            when TkIDENTIFIER, TkCONSTANT
              parser.process(statement_list(argument.tokens))
            end
          end
        end
      end
    end
  end

  private
  def statement_list(content)
    list = YARD::Parser::Ruby::Legacy::StatementList.new(content)
    return list unless content.is_a?(String)
    base_line = statement.line
    list.each do |stmt|
      stmt.tokens.each do |token|
        token.instance_variable_set(:@line_no, token.line_no + base_line)
      end
    end
    list
  end
end
