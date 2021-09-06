#
# Perform quiz
#

def do_quiz
  system("stty -echo")
  puts "\n\nAgain and again: Hear #{$num_quiz} note(s) from the scale and then try to replay ..."
  [2,1].each do |c|
    puts c
    sleep 1
  end

  all_wanted = nil
  first_lap_at_all = true
  $ctl_can_next = true
  loop do   # forever, sequence after sequence

    all_wanted = $scale_holes.sample($num_quiz)
    sleep 0.3

    unless first_lap_at_all
      ctl_issue "SPACE to pause"
      print "\e[#{$line_hint}H" 
      puts_pad
      print "\e[#{$line_listen}H"
    end

    all_wanted.each do |hole|
      file = "#{$sample_dir}/#{$harp[hole][:note]}.wav"
      poll_and_handle_kb true
      print "listen ... "
      play_sound file
    end
    print "\e[32mand !\e[0m"
    sleep 0.5
    print "\e[#{$line_listen}H" unless first_lap_at_all
    puts_pad ''
  
    system('clear') if first_lap_at_all
    print "\e[#{$line_comment2}H"
    puts_pad

    $ctl_loop = $opts[:loop]
    tstart = Time.now.to_f
    begin   # while looping over one sequence

      all_wanted.each_with_index do |wanted, idx|  # iterate over notes in sequence
        
        get_hole(
          if $ctl_loop
            if Time.now.to_f - tstart < 5
              "Looping"
            else
              "Looping these notes: #{all_wanted.join(' ')}"
            end
          else
            if $num_quiz == 1 
              "Play the note you have heard !"
            else
              "Play note number \e[32m#{idx+1}\e[0m from the sequence of #{$num_quiz} you have heard !"
            end
          end,
          -> (played, since) {[played == wanted,  # lambda_good_done
                               played == wanted && 
                               Time.now.to_f - since > 0.5]}, # do not return okay immediately
          
          -> () {$ctl_next},  # lambda_skip
          
          -> () do  # lambda_comment
            if $num_quiz == 1
              '.  .  .'
            else
              'Yes  ' + '*' * idx + '-' * (all_wanted.length - idx)
            end
          end,
          
          -> (tstart) do  # lambda_hint
            passed = Time.now.to_f - tstart
            if $ctl_loop
              puts_pad "Looping: The sequence is: #{all_wanted.join(' ')}" if passed > 4
            else
              if passed > 3
                print "Hint: Play \e[32m#{wanted}\e[0m (#{$harp[wanted][:note]})"
                print "  \e[2m...  the complete sequence is: #{all_wanted.join(' ')}\e[0m" if passed > 8
              else
                puts_pad
              end
            end
          end)
      end # notes in a sequence
        
      if $ctl_next
        print "\e[#{$line_issue}H"
        puts_pad '', true
        $ctl_loop = false
        first_lap_at_all = false
        next
      end
    
      print "\e[#{$line_comment}H"
      text = $ctl_next ? 'skipped' : 'Great !'
      figlet_out = %x(figlet -c -f smblock #{text})
      print "\e[32m"
      puts_pad figlet_out
      print "\e[0m"
      
      print "\e[#{$line_comment2}H"
      if $ctl_loop
        puts_pad "... \e[0m\e[32mand again\e[0m !"
      else
        puts_pad "#{$ctl_next ? 'T' : 'Right, t'}he sequence was: #{all_wanted.join(' ')}   ...   \e[0m\e[32mand next\e[0m !"
      end
    
      sleep 1
    end while $ctl_loop  # looping over one sequence

    $ctl_next = false
    first_lap_at_all = false
  end # sequence after sequence
end

