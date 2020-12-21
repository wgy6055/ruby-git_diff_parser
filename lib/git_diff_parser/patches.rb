require 'delegate'
module GitDiffParser
    # The array of patch
    class Patches < DelegateClass(Array)
        # @return [Patches<Patch>]
        def self.[](*ary)
            new(ary)
        end

        # @param contents [String] `git diff` result
        #
        # @return [Patches<Patch>] parsed object
        def self.parse(contents)
            body = false
            original_file_name = ''
            file_name = ''
            binary = false
            type = :modified
            patch = []
            lines = contents.lines
            line_count = lines.count
            parsed = new
            lines.each_with_index do |line, count|
                case parsed.scrub_string(line.chomp)
                when /^diff/
                    unless patch.empty? and original_file_name.empty? and file_name.empty?
                        parsed << Patch.new(patch.join("\n") + "\n", file: file_name, original_file: original_file_name, binary: binary, type: type)
                        patch.clear
                        file_name = ''
                        original_file_name = ''
                        binary = false
                        type = :modified
                    end
                    body = false
                when %r{^\-\-\- a/(?<file_name>.*)}
                    file_name = original_file_name.empty? ? Regexp.last_match[:file_name].rstrip : original_file_name
                    body = true
                when %r{^\+\+\+ b/(?<file_name>.*)}
                    file_name = Regexp.last_match[:file_name].rstrip
                    body = true
                when %r{^rename from (?<file_name>.*)}
                    original_file_name = Regexp.last_match[:file_name].rstrip
                    type = :renamed
                when %r{^rename to (?<file_name>.*)}
                    file_name = Regexp.last_match[:file_name].rstrip
                when '--- /dev/null'
                    type = :added
                when '+++ /dev/null'
                    type = :deleted
                when /^(?<body>[\ @\+\-\\].*)/
                    patch << Regexp.last_match[:body] if body
                    if !patch.empty? && body && line_count == count + 1
                        parsed << Patch.new(patch.join("\n") + "\n", file: file_name, original_file: original_file_name, binary: binary, type: type)
                        patch.clear
                        file_name = ''
                        original_file_name = ''
                        binary = false
                        type = :modified
                    end
                when %r{^Binary files (?<old_file_name>.*) and (?<new_file_name>.*) differ$}
                    binary = true
                    new_file_name = Regexp.last_match[:new_file_name].rstrip
                    # modified or added
                    file_name = new_file_name[2..-1] unless new_file_name == '/dev/null'
                end
            end
            unless original_file_name.empty? and file_name.empty?
                parsed << Patch.new(patch.join("\n") + "\n", file: file_name, original_file: original_file_name, binary: binary, type: type)
                patch.clear
                file_name = ''
                original_file_name = ''
                binary = false
                type = :modified
            end
            parsed
        end

        # @return [String]
        def scrub_string(line)
            if RUBY_VERSION >= '2.1'
                line.scrub
            else
                line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
            end
        end

        # @return [Patches<Patch>]
        def initialize(*args)
            super Array.new(*args)
        end

        # @return [Array<String>] file path
        def files
            map(&:file)
        end

        # @return [Array<String>] target sha1 hash
        def secure_hashes
            map(&:secure_hash)
        end

        # @param file [String] file path
        #
        # @return [Patch, nil]
        def find_patch_by_file(file)
            find { |patch| patch.file == file }
        end

        # @param secure_hash [String] target sha1 hash
        #
        # @return [Patch, nil]
        def find_patch_by_secure_hash(secure_hash)
            find { |patch| patch.secure_hash == secure_hash }
        end
    end
end
