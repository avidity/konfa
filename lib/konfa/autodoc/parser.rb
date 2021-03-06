require "method_source"

module Konfa
  module AutoDoc

    Variable = Struct.new(:name, :default, :comment)

    class Parser
      attr_reader :variables, :konfa_class

      def initialize(const)
        @variables = []
        @konfa_class = const
      end

      RE_VAR = /
        (?:
          :(\w+)\s*=>           # 0: Old style hash key declaration - :key => 'value'
          |                     #   - or -
          (\w+):                # 1: New style hash key declaration - key: 'value'
        )
        \s*
        (?:
          (?:'|")(.+?)(?:'|")   # 2: A string constant (FIXME: unless Backrefs to match leading and tailing quote)
          |                     #   - or -
          ([\w\@\:\.]+)         # 3: Bareword
        )
        \s*
        ,?                      #   - an optional comma -
        \s*
        (?:
          \#\s*(.+?)            # 4: An optional comment
          (?=\n\s*(?:           #  Match all lines to next entry,
             :\w+\s*=>          #  or end of hash declaraion. The lookahead
            |\}                 #  ensures we do not gobble up string for next match
            |\w+:
          ))
        )?
      /xm

      def parse
        @variables = []
        code = @konfa_class.method(:allowed_variables).source
        code.scan(RE_VAR).each do |tokens|
          @variables << Variable.new(
            tokens[0] || tokens[1],
            tokens[2] || tokens[3],
            trim_comment(tokens[4])
          )
        end

        variables
      end

      private

      def trim_comment(comment)
        unless comment.nil?
          comment.gsub!(/^\s*|\s*$/x, "")     # The ^ and $ rather than \A and \Z anchors are intentional
          comment.gsub!(/\n\#\s*/x, " ")      # Not sure if we should perserve line breaks. We currenty do not. Can be fixed by using a zero width look-behind
        end
        comment
      end
    end
  end
end
