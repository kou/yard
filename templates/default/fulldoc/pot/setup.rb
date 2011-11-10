require "pathname"

def init
  serializer = options[:serializer]
  base_path = Pathname.new(serializer.basepath).expand_path
  relative_base_path = Pathname.pwd.relative_path_from(base_path)
  serializer.serialize("yard.pot", generate_pot(relative_base_path.to_s))
end

def generate_pot(relative_base_path)
  pot = ""
  @extracted_objects = {}
  @messages = {}
  objects = options[:objects]
  objects.each do |object|
    extract_documents(object)
  end
  files = options[:files]
  files.each do |file|
    extract_paragraphs(file)
  end
  sorted_messages = @messages.sort_by do |message, options|
    sorted_locations = (options[:locations] || []).sort_by do |location|
      location
    end
    sorted_locations.first
  end
  sorted_messages.each do |message, options|
    options[:comments].compact.uniq.each do |comment|
      pot << "# #{comment}\n" unless comment.empty?
    end
    options[:locations].uniq.each do |path, line|
      pot << "#: #{relative_base_path}/#{path}:#{line}\n"
    end
    escaped_message = escape_message(message)
    escaped_message = escaped_message.gsub(/\n/, "\\\\n\"\n\"")
    pot << "msgid \"#{escaped_message}\"\n"
    pot << "msgstr \"\"\n"
    pot << "\n"
  end
  pot
end

def escape_message(message)
  message.gsub(/(\\|")/) do
    special_character = $1
    "\\#{special_character}"
  end
end

def add_message(text)
  @messages[text] ||= {:locations => [], :comments => []}
end

def extract_documents(object)
  return if @extracted_objects.has_key?(object)

  @extracted_objects[object] = true
  case object
  when CodeObjects::NamespaceObject
    object.children.each do |child|
      extract_documents(child)
    end
  end

  docstring = object.docstring
  unless docstring.empty?
    message = add_message(docstring)
    object.files.each do |path, line|
      message[:locations] << [path, docstring.line || line]
    end
    message[:comments] << object.path unless object.path.empty?
  end
  docstring.tags.each do |tag|
    next if tag.text.nil?
    next if tag.text.empty?
    message = add_message(tag.text)
    tag.object.files.each do |file|
      message[:locations] << file
    end
    tag_label = "@#{tag.tag_name}"
    tag_label << " [#{tag.types.join(', ')}]" if tag.types
    tag_label << " #{tag.name}" if tag.name
    message[:comments] << tag_label
  end
end

def extract_paragraphs(file)
  paragraph = []
  paragraph_start_line = 0
  File.open(file.filename) do |input|
    input.each_line do |line|
      case line
      when /\A\r?\n\z/
        next if paragraph.empty?
        message = add_message(paragraph.join("\n"))
        message[:locations] << [file.filename, paragraph_start_line]
        paragraph.clear
      else
        paragraph_start_line = input.lineno if paragraph.empty?
        paragraph << line.chomp
      end
    end
  end
  unless paragraph.empty?
    message = add_message(paragraph.join("\n"))
    message[:locations] << [file.filename, paragraph_start_line]
  end
end
