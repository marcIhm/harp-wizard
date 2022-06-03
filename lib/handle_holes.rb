#
# Sense holes played
#

# See  https://en.wikipedia.org/wiki/ANSI_escape_code  for formatting options

def sense_holes lambda_issue, lambda_good_done_was_good, lambda_skip, lambda_comment, lambda_hint, lambda_hole_for_inter
  samples = Array.new
  $move_down_on_exit = true
  longest_hole_name = $harp_holes.max_by(&:length)
  
  hole_start = Time.now.to_f
  hole = hole_since = hole_was_for_disp = nil
  hole_held = hole_held_before = hole_held_since = nil
  was_good = was_was_good = was_good_since = nil
  $chart = $chart_with_notes if $conf[:display] == :chart_notes
  $chart = $chart_with_scales if $conf[:display] == :chart_scales
  first_lap = true

  loop do   # until var done or skip
    system('clear') if $ctl_redraw
    if first_lap || $ctl_redraw
      print "\e[#{$line_issue}H#{lambda_issue.call.ljust($term_width - $ctl_issue_width)}\e[0m"
      $ctl_default_issue = "SPACE to pause; h for help"
      ctl_issue
      print "\e[#{$line_key}H" + text_for_key
      
      print_chart if $conf[:display] == :chart_notes || $conf[:display] == :chart_scales
      if $ctl_redraw && $ctl_redraw != :silent
        print "\e[#{$line_hint_or_message}H\e[2mTerminal [width, height] = [#{$term_width}, #{$term_height}] #{$term_width == $conf[:term_min_width] || $term_height == $conf[:term_min_height]  ?  "\e[0;91mON THE EDGE\e[0;2m of"  :  'is above'} minimum size [#{$conf[:term_min_width]}, #{$conf[:term_min_height]}]\e[K\e[0m"
        $message_shown = Time.now.to_f
      end
    end
    print "\e[#{$line_hint_or_message}HWaiting for frequency pipeline to start ..." if $first_lap_ever_get_hole

    freq = $opts[:screenshot]  ?  697  :  $freqs_queue.deq

    return if lambda_skip && lambda_skip.call()

    $ctl_redraw = false
    pipeline_catch_up if handle_kb_listen
    ctl_issue
    print "\e[#{$line_interval}H\e[2mInterval:   --  to   --  is   --  \e[K" if first_lap || $ctl_redraw

    handle_win_change if $ctl_sig_winch
    
    good = done = false
      
    hole_was_for_since = hole
    hole = nil
    hole, lbor, cntr, ubor = describe_freq(freq)
    hole_since = Time.now.to_f if !hole_since || hole != hole_was_for_since
    if hole != hole_held  &&  Time.now.to_f - hole_since > 0.1
      hole_held_before = hole_held
      write_to_journal(hole_held, hole_held_since) if $write_journal && $mode == :listen && regular_hole?(hole_held)
      if hole
        hole_held = hole
        hole_held_since = hole_since
      end
    end
    hole_for_inter = nil

    was_was_good = was_good
    good, done, was_good = if $opts[:screenshot]
                             [true, $ctl_can_next && Time.now.to_f - hole_start > 2, false]
                           elsif $opts[:no_progress]
                             [false, false, false] 
                           else
                             lambda_good_done_was_good.call(hole, hole_since)
                           end
    was_good_since = Time.now.to_f if was_good && was_good != was_was_good

    print "\e[2m\e[#{$line_frequency}HFrequency:  "
    just_dots_short = '.........:.........'
    format = "%6s Hz, %4s Cnt  [%s]\e[2m\e[K"
    if hole != :low && hole != :high
      dots, _ = get_dots(just_dots_short.dup, 2, freq, lbor, cntr, ubor) {|hit, idx| hit ? "\e[0m#{idx}\e[2m" : idx}
      cents = cents_diff(freq, cntr).to_i
      print format % [freq.round(1), cents, dots]
      hole_for_inter = lambda_hole_for_inter.call(hole_held_before, $hole_ref) if lambda_hole_for_inter
    else
      print format % ['--', '--', just_dots_short]
    end

    inter_semi, inter_text = describe_inter(hole_held, hole_for_inter)
    if inter_semi
      print "\e[#{$line_interval}HInterval: #{hole_for_inter.rjust(4)}  to #{hole_held.rjust(4)}  is #{inter_semi.rjust(5)}  " + ( inter_text ? ", #{inter_text}" : '' ) + "\e[K"
    else
      # let old interval be visible
    end

    hole_disp = ({ low: '-', high: '-'}[hole] || hole || '-')
    hole_color = "\e[0m\e[%dm" % get_hole_color_active(hole, good, was_good, was_good_since)
    hole_ref_color = "\e[#{hole == $hole_ref ?  92  :  91}m"
    case $conf[:display]
    when :chart_notes, :chart_scales
      update_chart(hole_was_for_disp, :inactive) if hole_was_for_disp && hole_was_for_disp != hole
      hole_was_for_disp = hole if hole
      update_chart(hole, :active, good, was_good, was_good_since)
    when :hole
      print "\e[#{$line_display}H\e[0m"
      print hole_color
      do_figlet hole_disp, 'mono12', longest_hole_name
    when :bend
      print "\e[#{$line_display + 2}H"
      if $hole_ref
        semi_ref = $harp[$hole_ref][:semi]
        just_dots_long = '......:......:......:......'
        dots, hit = get_dots(just_dots_long.dup, 4, freq,
                             semi2freq_et(semi_ref - 2),
                             semi2freq_et(semi_ref),
                             semi2freq_et(semi_ref + 2)) {|ok,idx| idx}
        print ( hit  ?  "\e[0m\e[32m"  :  "\e[0m\e[31m" )
        do_figlet dots, 'smblock', 'fixed:' + just_dots_long
      else
        print "\e[2m"
        do_figlet 'set ref first', 'smblock'
      end
    else
      fail "Internal error: #{$conf[:display]}"
    end

    print "\e[#{$line_hole}H\e[2m"
    if regular_hole?(hole)
      print "Hole: \e[0m%#{longest_hole_name.length}s\e[2m, Note: \e[0m%4s\e[2m" % [hole, $harp[hole][:note]]
    else
      print "Hole: %#{longest_hole_name.length}s, Note: %4s" % ['-- ', '-- ']
    end
    print ", Ref: %#{longest_hole_name.length}s" % [$hole_ref || '-- ']
    if $hole2rem || $opts[:add_scales]
      print ",  Rem: "
      if $opts[:add_scales] && $scale_holes.include?(hole)
        print "\e[0m"
        if $hole2flags[hole].include?(:both)
          print $scales.join(',')
        elsif $hole2flags[hole].include?(:main)
          print "\e[32m#{$scale}"
        else
          print "\e[34m#{$scales[1..-1].join(',')}"
        end
        print "\e[0m\e[2m#{$hole2rem && (';' + ($hole2rem[hole] || ''))}".strip
      else
        print ($hole2rem && $hole2rem[hole]) || '--'
      end
    end
    print "\e[K"

    if lambda_comment
      comment_color,
      comment_text,
      font,
      width_template,
      truncate =
      lambda_comment.call($hole_ref  ?  hole_ref_color  :  hole_color,
                          inter_semi,
                          inter_text,
                          hole && $harp[hole] && $harp[hole][:note],
                          hole_disp,
                          freq,
                          $hole_ref ? semi2freq_et($harp[$hole_ref][:semi]) : nil)
      print "\e[#{$line_comment}H#{comment_color}"
      do_figlet comment_text, font, width_template, truncate
    end

    if done
      print "\e[#{$line_call2}H"
      $move_down_on_exit = false
      return
    end

    if lambda_hint && !$message_shown
      hint = lambda_hint.call(hole) || ''
      print "\e[#{$line_call2}H\e[K" if $line_call2 > 0
      print "\e[#{$line_hint_or_message}H"
      maxlen = ( $mode == :listen  ?  $term_width - 4  :  2 * $term_width - 4 )
      if hint.length >= maxlen
        pspc = hint[maxlen - 8 .. maxlen - 2].index(' ')
        if pspc
          hint = hint[0 .. maxlen - 4 + pspc] + '...'
        else
          hint = hint[0 .. maxlen - 2] + '...'
        end
      end
      print "\e[2m#{hint}\e[0m\e[K"
    end      

    if $ctl_set_ref
      $hole_ref = regular_hole?(hole_held) ? hole_held : nil
      print "\e[#{$line_hint_or_message}H\e[2m#{$hole_ref ? 'Stored' : 'Cleared'} reference for intervals and display of bends\e[0m\e[K"
      $message_shown = Time.now.to_f
      $ctl_set_ref = false
    end
    
    if $ctl_change_display
      choices = [ $display_choices, $display_choices ].flatten
      $conf[:display] = choices[choices.index($conf[:display]) + 1]
      $chart = $chart_with_notes if $conf[:display] == :chart_notes
      $chart = $chart_with_scales if $conf[:display] == :chart_scales
      clear_area_display
      print_chart if $conf[:display] == :chart_notes || $conf[:display] == :chart_scales
      print "\e[#{$line_hint_or_message}H\e[2mDisplay is now #{$conf[:display].upcase}\e[0m\e[K"
      $message_shown = Time.now.to_f
      $ctl_change_display = false
    end
    
    if $ctl_can_change_comment && $ctl_change_comment
      choices = [ $comment_choices, $comment_choices ].flatten
      $conf[:comment_listen] = choices[choices.index($conf[:comment_listen]) + 1]
      clear_area_comment
      print "\e[#{$line_hint_or_message}H\e[2mComment is now #{$conf[:comment_listen].upcase}\e[0m\e[K"
      $message_shown = Time.now.to_f
      $ctl_change_comment = false
    end

    if $ctl_show_help
      clear_area_help
      puts "\e[#{$line_help}H\e[0mShort help on keys (see README.org for more details):\e[0m\e[32m\n"
      puts "      SPACE: pause               ctrl-l: redraw screen"
      puts "   TAB or d: change display (upper part of screen)"
      puts " S-TAB or c: change comment (lower, i.e. this, part of screen)" if $ctl_can_change_comment
      puts "          r: set reference hole       j: toggle writing of journal file"
      puts "          k: change key of harp       s: change scale"
      puts "          q: quit                     h: this help"
      if $ctl_can_next
        puts "\e[0mType any key to show more help ..."
        $ctl_kb_queue.clear
        $ctl_kb_queue.deq
        clear_area_help
        puts "\e[#{$line_help}H\e[0mMore help on keys:\e[0m\e[32m\n"
        puts "          .: replay current recording  ,: replay, holes only"
        puts "        :,p: replay recording but ignore '--partial'"
        puts "        RET: next sequence    BACKSPACE: previous sequence"
        puts "          i: toggle '--immediate'     l: loop current sequence"
        puts "        0,-: forget holes played  TAB,+: skip rest of sequence"
        puts "          #: toggle track progress in seq"
      end
      puts "\e[0mType any key to continue ..."
      $ctl_kb_queue.clear
      $ctl_kb_queue.deq
      ctl_issue 'continue', hl: true
      clear_area_help
      $ctl_show_help = false
    end

    if $ctl_can_loop && $ctl_start_loop
      $ctl_loop = true
      $ctl_start_loop = false
      print "\e[#{$line_issue}H#{lambda_issue.call.ljust($term_width - $ctl_issue_width)}\e[0m"
    end
    
    if $ctl_toggle_journal
      $write_journal = !$write_journal
      if $write_journal
        journal_start
        $journal_listen = Array.new
      else
        write_to_journal(hole_held, hole_held_since) if $mode == :listen && regular_hole?(hole_held)
        IO.write($journal_file, "All holes: #{$journal_listen.join(' ')}\n", mode: 'a') if $mode == :listen && $journal_listen.length > 0
        IO.write($journal_file, "Stop writing journal at #{Time.now}\n", mode: 'a')
      end
      ctl_issue "Journal #{$write_journal ? ' ON' : 'OFF'}"
      print "\e[#{$line_hint_or_message}H\e[2m"      
      print ( $write_journal  ?  "Appending to "  :  "Done with " ) + $journal_file
      print "\e[K"

      $ctl_toggle_journal = false

      print "\e[#{$line_key}H" + text_for_key      
      $message_shown = Time.now.to_f
    end

    if $ctl_change_key || $ctl_change_scale
      print "\e[#{$line_hint_or_message}H\e[J\e[0m\e[K"
      stop_kb_handler
      sane_term
      er = inp = nil
      begin
        if $ctl_change_key
          print "\e[0m\e[2mPlease enter \e[0mnew key\e[2m (current is #{$key}):\e[0m "
          inp = STDIN.gets.chomp
          inp = $key.to_s if inp == ''
          er = check_key_and_set_pref_sig(inp)
        else
          scales = scales_for_type($type)
          print "\e[0m\e[2mPlease enter \e[0mnew scale\e[2m (one of #{scales.join(', ')}; current is #{$scale}):\e[0m "
          inp = STDIN.gets.chomp
          inp = $scale if inp == ''
          scale = match_or(inp, scales) do |none, choices|
            er = "Given scale #{none} is none of #{choices}"
          end            
        end
        if er
          puts "\e[91m#{er}"
        else
          if $ctl_change_key
            $key = inp.to_sym
          else
            $scale = inp
          end
        end
      end while er
      $harp, $harp_holes, $harp_notes, $scale_holes, $scale_notes, $hole2rem, $hole2flags, $semi2hole, $note2hole, $intervals, $dsemi_harp = read_musical_config
      $chart, $hole2chart = read_chart
      set_global_vars_late
      $freq2hole = read_calibration
      start_kb_handler
      prepare_term
      $ctl_redraw = :silent
      system('clear')
      print "\e[3J" # clear scrollback
      print "\e[#{$line_key}H" + text_for_key
      if $ctl_change_key
        print "\e[#{$line_hint_or_message}H\e[2mChanged key of harp to \e[0m#{$key}\e[K"
      else
        print "\e[#{$line_hint_or_message}H\e[2mChanged scale in use to \e[0m#{$scale}\e[K"
      end
      $message_shown = Time.now.to_f
      $ctl_change_key = $ctl_change_scale = false
    end

    if $ctl_quit
      print "\e[#{$line_hint_or_message}H\e[K\e[0mTerminating on user request (quit) ...\n\n"
      exit 0
    end

    if done || ( $message_shown && Time.now.to_f - $message_shown > 8 )
      print "\e[#{$line_hint_or_message}H\e[K"
      $message_shown = false
    end
    first_lap = $first_lap_ever_get_hole = false
  end  # loop until var done or skip
end


def text_for_key
  text = "\e[2mMode: #{$mode} #{$type} #{$key}"
  if $opts[:add_scales]
    text += "\e[0m"
    text += " \e[32m#{$scale}"
    text += "\e[0m\e[2m," + $scales[1..-1].map {|s| "\e[0m\e[34m#{s}\e[0m\e[2m"}.join(',')
    text += "\e[0m,all\e[2m"
  else
    text += " #{$scale}"
  end
  text += ', jour: ' + ( $write_journal  ?  'on' : 'off' )
  text += ", part: #{$opts[:partial]}" if $opts[:partial]
  text += "\e[K"
end


def regular_hole? hole
  hole && hole != :low && hole != :high
end


def get_dots dots, delta, freq, low, middle, high
  hdots = (dots.length - 1)/2
  if freq > middle
    pos = hdots + ( hdots + 1 ) * (freq - middle) / (high - middle)
  else
    pos = hdots - ( hdots + 1 ) * (middle - freq) / (middle - low)
  end

  hit = ((hdots - delta  .. hdots + delta) === pos )
  dots[pos] = yield( hit, 'I') if pos > 0 && pos < dots.length
  return dots, hit
end