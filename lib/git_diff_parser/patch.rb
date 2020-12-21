module GitDiffParser
    # Parsed patch
    class Patch
        RANGE_INFORMATION_LINE = /^@@ -(?<old_line_number>\d+)(,\d+)? \+(?<line_number>\d+)(,\d+)?/
        MODIFIED_LINE = /^\+(?!\+|\+)/
        REMOVED_LINE = /^[-]/
        NOT_REMOVED_LINE = /^[^-]/
        UNCHANGED_LINE = /^\s/

        attr_accessor :file, :original_file, :body, :secure_hash, :binary, :type
        # @!attribute [rw] file
        #   @return [String, nil] file path or nil
        # @!attribute [rw] body
        #   @return [String, nil] patch section in `git diff` or nil
        #   @see #initialize
        # @!attribute [rw] secure_hash
        #   @return [String, nil] target sha1 hash or nil

        # @param body [String] patch section in `git diff`.
        #   GitHub's pull request file's patch.
        #   GitHub's commit file's patch.
        #
        #    <<-BODY
        #    @@ -11,7 +11,7 @@ def valid?
        #
        #       def run
        #         api.create_pending_status(*api_params, 'Hound is working...')
        #    -    @style_guide.check(pull_request_additions)
        #    +    @style_guide.check(api.pull_request_files(@pull_request))
        #         build = repo.builds.create!(violations: @style_guide.violations)
        #         update_api_status(build)
        #       end
        #    @@ -19,6 +19,7 @@ def run
        #       private
        #
        #       def update_api_status(build = nil)
        #    +    # might not need this after using Rubocop and fetching individual files.
        #         sleep 1
        #         if @style_guide.violations.any?
        #           api.create_failure_status(*api_params, 'Hound does not approve', build_url(build))
        #    BODY
        #
        # @param options [Hash] options
        # @option options [String] :file file path
        # @option options [String] 'file' file path
        # @option options [String] :original_file file path before rename
        # @option options [String] 'original_file' file path before rename
        # @option options [String] :secure_hash target sha1 hash
        # @option options [String] 'secure_hash' target sha1 hash
        # @option options [Boolean] :binary binary file?
        # @option options [Boolean] 'binary' binary file?
        # @option options [String] :type patch type (:modified, :added, :deleted, :renamed)
        # @option options [String] 'type' patch type (:modified, :added, :deleted, :renamed)
        #
        # @see https://developer.github.com/v3/repos/commits/#get-a-single-commit
        # @see https://developer.github.com/v3/pulls/#list-pull-requests-files
        def initialize(body, options = {})
            @body = body || ''
            @file = options[:file] || options['file'] if options[:file] || options['file']
            @secure_hash = options[:secure_hash] || options['secure_hash'] if options[:secure_hash] || options['secure_hash']
            @original_file = options[:original_file] || options['original_file'] if options[:original_file] || options['original_file']
            @binary = options[:binary]
            @type = options[:type] || options['type'] if options[:type] || options['type']
        end

        # @return [Array<Line>] changed lines
        def changed_lines
            line_number = 0

            lines.each_with_index.inject([]) do |lines, (content, patch_position)|
                case content
                when RANGE_INFORMATION_LINE
                    line_number = Regexp.last_match[:line_number].to_i
                when MODIFIED_LINE
                    line = Line.new(
                        content: content,
                        number: line_number,
                        patch_position: patch_position
                    )
                    lines << line
                    line_number += 1
                when NOT_REMOVED_LINE
                    line_number += 1
                end

                lines
            end
        end

        # @return [Array<Line>] removed lines
        def removed_lines
            line_number = 0

            lines.each_with_index.inject([]) do |lines, (content, patch_position)|
                case content
                when RANGE_INFORMATION_LINE
                    line_number = Regexp.last_match[:old_line_number].to_i
                when REMOVED_LINE
                    line = Line.new(
                        content: content,
                        number: line_number,
                        patch_position: patch_position
                    )
                    lines << line
                    line_number += 1
                when UNCHANGED_LINE
                    line_number += 1
                end

                lines
            end
        end

        # @return [Array<Integer>] changed line numbers
        def changed_line_numbers
            changed_lines.map(&:number)
        end

        # @param line_number [Integer] line number
        #
        # @return [Integer, nil] patch position
        def find_patch_position_by_line_number(line_number)
            target = changed_lines.find { |line| line.number == line_number }
            return nil unless target
            target.patch_position
        end

        # @return [Array<String>] 获取 git diff 中一个文件维度下的所有 diff，包含 +/- 符号
        def diff_lines
            body.lines
        end

        # 是否被重命名
        def renamed?
            @type == :renamed
        end

        # 是否为新增文件
        def added?
            @type == :added
        end

        # 是否为删除文件
        def deleted?
            @type == :deleted
        end

        # 是否为修改文件
        def modified?
            @type == :modified
        end

        # 是否为二进制文件
        def binary?
            @binary
        end

        private

        def lines
            @body.lines
        end
    end
end
