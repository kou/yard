require "fast_gettext"

module YARD
  module I18N
    class << self
      def setup(locale_paths=[])
        available_locales = []
        repository_options = []

        locale_paths = locale_paths.uniq
        locale_paths.each do |locale_path|
          names = []
          Dir.glob(File.join(locale_path, "*", "*.po")).each do |po|
            names << File.basename(po, ".po")
            available_locales << File.basename(File.dirname(po))
          end
          names.uniq.each do |name|
            repository_options << [
              name,
              {
                :path => locale_path,
                :type => :po,
              }
            ]
          end
        end
        yard_locale_path = File.join(YARD::ROOT, "..", "locale")
        Dir.glob(File.join(yard_locale_path, "*", "yard.po")).each do |po|
          available_locales << File.basename(File.dirname(po))
        end
        FastGettext.available_locales = available_locales.uniq
        repository_options << [
          "yard",
          {
            :path => yard_locale_path,
            :type => :po,
          }
        ]
        repository_options << [
          "logger",
          {
            :type => :logger,
            :callback => lambda do |key|
              puts "missing translation: #{key.inspect}"
            end
          }
        ]
        repositories = repository_options.map do |name, options|
          FastGettext::TranslationRepository.build(name, options)
        end
        FastGettext.add_text_domain("combined",
                                    :type => :chain,
                                    :chain => repositories)
        FastGettext.text_domain = "combined"
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

      def N_(message)
        message
      end
    end
  end
end
