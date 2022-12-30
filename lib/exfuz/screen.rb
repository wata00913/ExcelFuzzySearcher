# frozen_string_literal: true

require 'curses'

module Exfuz
  class Screen
    attr_reader :query

    def initialize(status = nil, caret = nil, key_map = nil,
                   candidates = nil)
      @status = status
      @prev_loaded = @status.loaded
      @key_map = key_map
      @query = Exfuz::Query.new(caret || [0, 0])
      @cmd = Exfuz::FuzzyFinderCommand.new
      @candidates = candidates

      register_event
    end

    def status
      @status.to_s
    end

    def init
      Curses.init_screen
      # キー入力の文字を画面に反映させない
      Curses.noecho
      # 入力の待機時間(milliseconds)
      Curses.timeout = 100
      draw
      Curses.refresh
    end

    def rerender
      @prev_loaded = @status.loaded
      refresh
    end

    def refresh
      draw
      Curses.refresh
    end

    def wait_input
      @ch = Curses.getch
      # 待機時間内に入力されない場合
      return unless @ch

      handle_event(@ch)
    end

    # 表示内容の変更検知を判定する
    def changed_state?
      @prev_loaded < @status.loaded
    end

    def closed?
      Curses.closed?
    end

    def close
      Curses.close_screen
    end

    # event
    def start_cmd
      @cmd.run do |fiber|
        @candidates.each_by_filter(@query.text) do |idx, c|
          fiber.resume("#{idx}:#{c.to_line}")
        end
      end
      Curses.clear
      init
    end

    def delete_char
      @query.delete
      refresh
    end

    def move_left
      @query.left
      refresh
    end

    def move_right
      @query.right
      refresh
    end

    def finish
      close
    end

    def insert_char(char)
      @query.add(char)
      refresh
    end

    private

    def handle_event(ch)
      input = if Exfuz::Key.can_convert_to_name_and_char?(ch)
                ch
              else
                chs = [ch]
                # スレッドセーフでないかも
                # 稀に正常にchが読み込めない場合があった
                loop do
                  remaining = Curses.getch
                  break if remaining.nil?

                  chs << remaining
                end
                chs
              end

      name, char = Exfuz::Key.input_to_name_and_char(input)

      char.nil? ? @key_map.pressed(name) : @key_map.pressed(name, char)
    end

    def register_event
      @key_map.add_event_handler(Exfuz::Key::CTRL_R, self, func: :start_cmd)
      @key_map.add_event_handler(Exfuz::Key::CTRL_E, self, func: :finish)
      @key_map.add_event_handler(Exfuz::Key::LEFT, self, func: :move_left)
      @key_map.add_event_handler(Exfuz::Key::RIGHT, self, func: :move_right)
      @key_map.add_event_handler(Exfuz::Key::BACKSPACE, self, func: :delete_char)
      @key_map.add_event_handler(Exfuz::Key::CHAR, self, func: :insert_char)
    end

    def draw
      print_head_line

      reset_caret
    end

    def reset_caret
      Curses.setpos(*@query.caret)
    end

    def print_head_line
      # 前回の入力内容を保持してないためクエリの全文字を再描画
      Curses.setpos(0, 0)
      Curses.addstr(@query.line)

      col = Curses.cols - status.size
      Curses.setpos(0, col)
      Curses.addstr(status)
    end
  end
end

def main
  require_relative './status'
  screen = Exfuz::Screen.new(Exfuz::Status.new(10))
  screen.init
  until screen.closed?
    # キー入力を待機
    screen.handle_input
  end
  screen.close
end

main if __FILE__ == $0
