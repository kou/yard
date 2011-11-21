require "fast_gettext"

module YARD
  module I18N
    class << self
      def setup(options={})
        locale_paths = options[:locale_paths] || ["locale"]

        collector = LocaleInfoCollector.new
        locale_paths.uniq.each do |locale_path|
          collector.collect(locale_path, "*")
        end
        yard_locale_path = File.join(YARD::ROOT, "..", "system-locale")
        collector.collect(yard_locale_path, "yard")

        available_locales = ["en"] | collector.available_locales
        language = options[:language] || guess_language
        if language
          FastGettext.locale = language
          available_locales |= [language]
        end
        FastGettext.available_locales = available_locales

        repositories = collector.repositories
        if options[:report_missing_translations]
          repositories << logger_repository
        end
        FastGettext.add_text_domain("combined",
                                    :type => :chain,
                                    :chain => repositories)
        FastGettext.text_domain = "combined"
      end

      private
      def guess_language
        locale = ENV["LC_ALL"] || ENV["LC_MESSAGES"] || ENV["LANG"]
        locale = locale.sub(/(?:_[A-Z]{2})?(?:\..+)?\z/i, "") if locale
        locale
      end

      def logger_repository
        callback = lambda do |key|
          puts "missing translation: #{key.inspect}"
        end
        FastGettext::TranslationRepository.build("logger",
                                                 :type => :logger,
                                                 :callback => callback)
      end
    end

    class LocaleInfoCollector
      def initialize
        @available_locales = []
        @repository_options = []
      end

      def collect(base_dir, name)
        detected_names = []
        Dir.glob(File.join(base_dir, "*", "#{name}.po")).each do |po|
          detected_names << File.basename(po, ".po")
          @available_locales << File.basename(File.dirname(po))
        end
        detected_names.uniq.each do |detected_name|
          @repository_options << [
            detected_name,
            {
              :path => base_dir,
              :type => :po,
            }
          ]
        end

        def available_locales
          @available_locales.uniq
        end

        def repositories
          @repository_options.map do |name, options|
            FastGettext::TranslationRepository.build(name, options)
          end
        end
      end
    end

    class Text
      def initialize(input, options={})
        @input = input
        @options = options
      end

      def extract_messages
        paragraph = ""
        paragraph_start_line = 0
        line_no = 0
        in_header = @options[:have_header]

        @input.each_line do |line|
          line_no += 1
          if in_header
            case line
            when /^#!\S+\s*$/
              in_header = false unless line_no == 1
            when /^\s*#\s*@(\S+)\s*(.+?)\s*$/
              name, value = $1, $2
              yield(:attribute, name, value, line_no)
            else
              in_header = false
              next if line.chomp.empty?
            end
            next if in_header
          end

          case line
          when /^\s*$/
            next if paragraph.empty?
            yield(:paragraph, paragraph.rstrip, paragraph_start_line)
            paragraph = ""
          else
            paragraph_start_line = line_no if paragraph.empty?
            paragraph << line
          end
        end
        unless paragraph.empty?
          yield(:paragraph, paragraph.rstrip, paragraph_start_line)
        end
      end

      def translate(&block)
        paragraph = ""
        line_no = 0
        in_header = @options[:have_header]

        @input.each_line do |line|
          line_no += 1
          if in_header
            case line
            when /^#!\S+\s*$/
              if line_no == 1
                yield(:markup, line)
              else
                in_header = false
              end
            when /^(\s*#\s*@\S+\s*)(.+?)(\s*)$/
              prefix, value, suffix = $1, $2, $3
              yield(:attribute, prefix, value, suffix)
            else
              in_header = false
              if line.strip.empty?
                yield(:empty_line, line)
                next
              end
            end
            next if in_header
          end

          case line
          when /^\s*$/
            yield(:empty_line, line)
            next if paragraph.empty?
            translate_emit_paragraph_event(paragraph, &block)
            paragraph = ""
          else
            paragraph << line
          end
        end
        unless paragraph.empty?
          translate_emit_paragraph_event(paragraph, &block)
        end
      end

      private
      def translate_emit_paragraph_event(paragraph)
        match_data = /(\s*)\z/.match(paragraph)
        if match_data
          yield(:paragraph, match_data.pre_match)
          yield(:empty_line, match_data[1])
        else
          yield(:paragraph, paragraph)
        end
      end
    end

    module Translation
      class << self
        def included(base)
          base.extend(self)
        end
      end

      module_function
      def _(message)
        FastGettext::Translation._(message)
      end

      def s_(message)
        FastGettext::Translation.s_(message)
      end

      def N_(message)
        message
      end
    end
  end
end
