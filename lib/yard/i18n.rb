require "fast_gettext"

module YARD
  module I18N
    class << self
      def setup(locale_paths=[])
        collector = LocaleInfoCollector.new
        locale_paths.uniq.each do |locale_path|
          collector.collect(locale_path, "*")
        end
        yard_locale_path = File.join(YARD::ROOT, "..", "locale")
        collector.collect(yard_locale_path, "yard")

        FastGettext.available_locales = collector.available_locales

        repositories = collector.repositories
        FastGettext.add_text_domain("combined",
                                    :type => :chain,
                                    :chain => repositories)
        FastGettext.text_domain = "combined"
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
