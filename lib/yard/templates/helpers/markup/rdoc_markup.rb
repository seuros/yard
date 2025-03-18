# frozen_string_literal: true
require 'thread'

gem 'rdoc', '>= 6.0'
require 'rdoc'
require 'rdoc/markup'
require 'rdoc/markup/to_html'

module YARD
  module Templates
    module Helpers
      module Markup
        class RDocMarkup
          MARKUP = RDoc::Markup

          attr_accessor :from_path

          # Class instance variables initialized once
          @mutex = Mutex.new
          @formatter = nil
          @markup = nil

          class << self
            attr_reader :mutex, :formatter, :markup

            def initialize_markup_components
              return if @markup && @formatter

              @mutex.synchronize do
                @formatter ||= RDocMarkupToHtml.new
                @markup ||= MARKUP.new
              end
            end
          end

          def initialize(text)
            @text = text
            self.class.initialize_markup_components
          end

          def to_html
            html = nil
            self.class.mutex.synchronize do
              self.class.formatter.from_path = from_path
              html = self.class.markup.convert(@text, self.class.formatter)
            end

            fix_dash_dash(fix_typewriter(html))
          end

          private

          # Fixes RDoc behaviour with ++ only supporting alphanumeric text.
          def fix_typewriter(text)
            code_tags = 0
            text.gsub(%r{<(/)?(pre|code|tt)|(\s|^|>)\+(?! )([^\n\+]{1,900})(?! )\+}) do |str|
              closed = $1
              tag = $2
              first_text = $3
              type_text = $4

              if tag
                code_tags += (closed ? -1 : 1)
                next str
              end
              next str unless code_tags == 0
              "#{first_text}<tt>#{type_text}</tt>"
            end
          end

          # Don't allow -- to turn into &#8212; element (em dash)
          def fix_dash_dash(text)
            text.gsub(/&#8212;(?=\S)/, '--')
          end
        end

        # Specialized ToHtml formatter for YARD
        class RDocMarkupToHtml < RDoc::Markup::ToHtml
          attr_accessor :from_path

          def initialize
            options = RDoc::Options.new
            options.pipe = true
            super(options)

            # The hyperlink detection state
            @hyperlink = false
          end

          # Disable auto-link of URLs
          def handle_special_HYPERLINK(special)
            @hyperlink ? special.text : super
          end

          def accept_paragraph(*args)
            par = args.last
            text = par.respond_to?(:txt) ? par.txt : par.text
            @hyperlink = text =~ /\{(https?:|mailto:|link:|www\.)/
            super
          end

          # Override gen_url to support from_path in relative links
          def gen_url(url, text)
            scheme, path, id = parse_url(url)

            if scheme == 'link' && !path.start_with?('/') && !from_path.nil? && !from_path.empty?
              # Make the path relative to from_path for link: URLs
              path = File.expand_path(path, File.dirname(from_path))
            end

            super("#{scheme}:#{path}#{id}", text)
          end

          # Override parse_url to handle custom schemes
          def parse_url(url)
            case url
            when /^mailto:(.*)$/i
              ['mailto', $1, '']
            when /^(https?|ftp|irc):(.*)$/i
              [$1, $2, '']
            when /^link:(.*)$/i
              ['link', $1, '']
            else
              ['http', url, '']
            end
          end
        end
      end
    end
  end
end
