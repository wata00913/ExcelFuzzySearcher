# frozen_string_literal: true

require 'pathname'

module Exfuz
  class BookName
    attr_reader :absolute_path

    def initialize(file_name)
      @absolute_path = File.absolute_path(file_name)
    end

    def ==(other)
      absolute_path == other.absolute_path
    end

    def relative_path
      Pathname.new(@absolute_path).relative_path_from(Dir.pwd).to_s
    end
  end
end
