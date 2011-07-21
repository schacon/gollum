module Gollum
  class Document

    # wiki object used as a base for the document
    attr_reader :wiki

    # document settings
    attr_reader :settings

    # document settings file path
    attr_reader :settings_file

    # document generation output path
    attr_reader :output_path

    def initialize(wiki, options = {})
      @wiki = wiki
      @settings_file = options[:settings_file] || '_Document.yml'
      @output_path = options[:output_path]

      @base_html_file = 'base.html'
      @checksums_file = 'checksums.yml'
      @toc_file = 'toc.yml'

      parse_settings
    end

    # filter and order the wiki pages according to the document settings file
    def pages
      toc = []
      p = @wiki.pages
      @settings['toc'].each do |entry|
        toc << p.select { |page| wc_match(page.path, entry + '*') }
      end
      toc.flatten.uniq.compact
    end

    def generate(type = :html)
      path = generate_base
      case type
      when :base
        return path
      when :html
        return generate_html
      end
    end

    def toc
      generate_base
      toc = parse_yml_file(outpath(@toc_file))
    end

    private

    # - write the base consolidated html content file
    # - write table of contents file generated from the content (h1, h2, h3)
    # - copy referenced images and files into assets directories
    # - write checksum of when these were generated
    def generate_base
      version = @wiki.version_sha

      checksums_path = outpath(@checksums_file)
      checksums = parse_yml_file(checksums_path)

      outfile_path = outpath(@base_html_file)

      return outfile_path if ::File.file?(outfile_path) && (checksums[:base] == version)

      of = ::File.open(outfile_path, 'w+')
      pages.each do |page|
        of.write "<!-- " + page.path + "-->\n"
        of.write insert_section_ids(page.formatted_data)
        of.write "\n\n"
      end
      of.close

      generate_toc

      checksums[:base] = version
      save_yml_file(checksums_path, checksums)

      outfile_path
    end

    # read the base html file and generate a table of contents
    # based on the header tags
    def generate_toc
      toc = []
      source = ::File.read(outpath(@base_html_file))
      source.scan(/\<h([1|2|3]) id=\"(.*?)\"\>(.*?)\<\/h[1|2|3]\>/).each do |header|
        sec = {'id' => header[1], 'name' => strip_html(header[2]), 'subsections' => []}
        if header[0] == '1' 
          toc << sec
        elsif header[0] == '2'
          toc.last['subsections'] << sec
        else
          subtoc = toc.last['subsections'].last['subsections'] << sec
        end
      end
      save_yml_file(outpath(@toc_file), toc)
      toc
    end

    # take the generated base html document and insert ids into the 
    # headers that do not have them
    def insert_section_ids(data)
      @section_ids ||= {}
      data.gsub(/\<h([1|2|3])>(.*?)\<\/h[1|2|3]\>/).each do |header|
        level = $1
        title = $2
        base_id = id = strip_html(title.gsub(' ', '-'))
        counter = 1
        while @section_ids[id]
          counter += 1
          id = base_id + '-' + counter.to_s
        end
        @section_ids[id] = true
        "<h#{level} id=\"#{id}\">#{title}</h#{level}>"
      end
    end

    def generate_html
    end

    def strip_html(str)
      str.gsub(/<\/?[^>]*>/, "")
    end

    def outpath(file)
      ::File.join(@output_path, file)
    end

    def parse_yml_file(file)
      return {} if !::File.file? file
      yml = ::File.read(file)
      YAML::parse(yml).transform
    end

    def save_yml_file(file, data)
      ::File.open(file, 'w+') do |f|
        f.write YAML::dump(data)
      end
    end

    def parse_settings
      yml = @wiki.file(@settings_file).raw_data
      @settings = YAML::parse(yml).transform
    end

    # do wildcard matching on string from pattern
    # escape everything but *, ^ and $
    # return true if it matches, 
    def wc_match(string, pattern)
      pattern = Regexp.escape(pattern).gsub('\*','.*?').gsub('\^', '^').gsub('\$', '$')
      matcher = Regexp.new pattern, Regexp::IGNORECASE
      !!(matcher =~ string)
    end
    

  end
end

