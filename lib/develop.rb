#
#  Utility functions for the maintainer or developer of harpwise
#

def do_develop to_handle

  tasks_allowed = %w(man diff selftest)
  err "Can only do 1 task at a time, but not #{to_handle.length}; too many arguments: #{to_handle}" if to_handle.length > 1
  err "Unknown task #{to_handle[0]}, only these are allowed: #{tasks_allowed}" unless tasks_allowed.include?(to_handle[0])

  case to_handle[0]
  when 'man'
    task_man
  when 'diff'
    task_diff
  when 'selftest'
    task_selftest
  end
end


def task_man
  types_with_scales = get_types_with_scales
  File.write("#{$dirs[:install_devel]}/man/harpwise.1",
             ERB.new(IO.read("#{$dirs[:install_devel]}/resources/harpwise.man.erb")).result(binding).chomp)

  puts
  system("ls -l #{$dirs[:install_devel]}/man/harpwise.1")
  puts "\nTo read it:\n\n  man -l #{$dirs[:install_devel]}/man/harpwise.1\n\n"
  puts "\nRedirect stdout to see any errors:\n\n  man --warnings -E UTF-8 -l -Tutf8 -Z -l #{$dirs[:install_devel]}/man/harpwise.1 >/dev/null\n\n"
end


def task_diff
  types_with_scales = get_types_with_scales
  seen = false

  lines = Hash.new
  line = Hash.new
  srcs = [:usage, :man]

  # Modifications for usage
  erase_line_usage_if_part = [/Version \d/]

  # Modifications for man
  seen_man = {:desc => [/^DESCRIPTION$/, false],
              :prim_start => [/The primary documentation/, false],
              :prim_end => [/not available as man-pages/, false],
              :exa_start => [/^EXAMPLES$/, false],
              :exa_end => [/^COPYRIGHT$/, false]}
  
  erase_part_man = ['<hy>', '<beginning of page>']
  erase_line_man = %w(MODE ARGUMENTS OPTIONS)
  replaces_man = {'SUGGESTED READING' => 'SUGGESTED READING:',
                  'USER CONFIGURATION' => 'USER CONFIGURATION:'}

  #
  # Bring usage information and man page into canonical form by
  # applying modifications
  #

  # only a simple modification
  lines[:usage] = ERB.new(IO.read("#{$dirs[:install_devel]}/resources/usage.txt")).
                    result(binding).lines.
                    map do |l|
                      erase_line_usage_if_part.any? {|rgx| l.match?(rgx)} ? nil : l
                    end.compact.
                    map {|l| l.chomp.strip.downcase}.
                    reject(&:empty?)

  # long modification pipeline
  lines[:man] = %x(groff -man -a -Tascii #{$dirs[:install_devel]}/man/harpwise.1).lines.
                  map {|l| l.strip}.
                  # use only some sections of lines
                  map do |l|
                    newly_seen = false
                    seen_man.each do |k,v|
                      if l.strip.match?(v[0])
                        v[1] = true
                        newly_seen = true
                      end
                    end
                    if newly_seen
                      nil
                    elsif !seen_man[:desc][1]
                      nil
                    elsif seen_man[:prim_start][1] && !seen_man[:prim_end][1]
                      nil
                    elsif seen_man[:exa_start][1] && !seen_man[:exa_end][1]
                      nil
                    else
                      l
                    end
                  end.compact.
                  # erase and replace
                  map do |l|
                    erase_part_man.each {|e| l.gsub!(e,'')}
                    l
                  end.
                  map do |l|
                    erase_line_man.any? {|e| e == l.strip} ? nil : l
                  end.compact.
                  map {|l| replaces_man[l] || l}.
                  map {|l| l.strip.downcase}.reject(&:empty?).compact

  srcs.each {|s| line[s] = lines[s].shift}

  last_common = Array.new
  
  while srcs.all? {|s| lines[s].length > 0}
    clen = 0
    clen += 1 while line[:usage][clen] && line[:usage][clen] == line[:man][clen]
    if clen > 0
      last_common << [line[:usage][0, clen], line[:man][0, clen]] 
      srcs.each do |s|
        line[s][0, clen] = ''
        line[s].strip!
        line[s] = lines[s].shift.strip if line[s].empty?
      end
    else
      pp last_common[-2 .. -1]
      pp [line[:usage], line[:man]]
      fail "#{srcs} differ; see above"
    end
  end
end


def task_selftest

  puts
  puts_underlined "Performing selftest"

  puts_underlined "Check installation", '-', dim: false
  check_installation verbose: true

  puts
  puts_underlined "Figlet output", '-', dim: false
  expected_figlet_outputs = [ '▀▀ ▘▝ ▘▀▀  ▘▝▀ ▝▀ ▘ ▘',
                              '  ████▄██▄   ▄████▄   ██▄████▄   ▄████▄      ██           ██',
                              '  █ █ █  █▀ ▀█  █▀  █  █▀ ▀█  █▄  ▄█',
                              Array.new(10,'???') ].flatten
  $early_conf[:figlet_fonts].each do |font|
    output = get_figlet_wrapped(font, font)
    expected = expected_figlet_outputs.shift
    found = output[3]
    pp output
    found[expected] or err("Unexpected figlet output for font #{font}: #{found} does not contain #{expected}")
  end

  test_hole = '+1'
  puts
  puts_underlined "Generating sound with sox", '-', dim: false
  synth_sound test_hole, $helper_wave
  system("ls -l #{$helper_wave}")

  puts
  puts_underlined "Frequency pipeline from previously generated sound", '-', dim: false
  cmd = get_pipeline_cmd(:sox, $helper_wave)
  puts "Command is: #{cmd}"
  puts
  puts "Note: Some errors in first lines are expected, because\n      multiple codecs are tried and some of them give up."
  puts
  _, stdout_err, wait_thr  = Open3.popen2e(cmd)
  output = Array.new
  loop do
    line = stdout_err.gets
    output << line
    if output.length == 40
      begin
        line or raise ArgumentError
        line.split(' ', 2).each {|f| Float(f)}
      rescue ArgumentError
        err "Unexpected output of: #{cmd}\n:#{output.compact}"
      end
      Process.kill('KILL',wait_thr.pid)
      break
    end
  end
  puts 'Some samples from the middle of the interval:'
  mid = output.length / 2
  pp output[mid - 5 .. mid + 5]
  puts
  puts "Remark: this may be compared with"
  puts " - Time-slice of #{$time_slice_secs}"
  puts " - Frequency (et) for test-hole #{test_hole} of #{semi2freq_et($harp[test_hole][:semi])}"

  puts
  fail "Internal error: no user config directory yet: #{$dirs[:data]}" unless File.exist?($dirs[:data])
  if $dirs_data_created
    puts "Remark: user config directory has been created: #{$dirs[:data]}"
  else
    puts "Remark: user config directory already existed: #{$dirs[:data]}"
  end

  puts
  puts
  puts "Selftest done."
  puts
end
