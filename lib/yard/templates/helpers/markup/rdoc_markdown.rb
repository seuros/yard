# frozen_string_literal: true
module YARD
  module Templates
    module Helpers
      module Markup
        begin
          require 'rdoc'
          require 'rdoc/markdown'
        rescue LoadError
          raise NameError, "could not load RDoc Markdown support (rdoc is too old)"
        end

        class RDocMarkdown < RDocMarkup
          def initialize(text)
            super RDoc::Markdown.new.parse(text)
          end

          def fix_typewriter(html) html end
        end
      end
    end
  end
end
