#
# Immediately related to sound
#

def record_sound secs, file, **opts
  duration_clause = secs < 1 ? "-s #{(secs.to_f * $sample_rate).to_i}" : "-d #{secs}"
  output_clause = (opts[:silent] && $opts[:debug] <= 2) ? '>/dev/null 2>&1' : ''
  system(dbg "arecord -r #{$sample_rate} #{duration_clause} #{file} #{output_clause}") or fail 'arecord failed'
end


def play_sound file
  sys(dbg "aplay #{file}")
end


def run_aubiopitch file, extra = nil
  %x(aubiopitch --pitch mcomb #{file} 2>&1)
end


def autoedit file
  f = Hash.new {|h,k| fail "Key '#{k.inspect}' does not exist"}
  
  [ :vol_ad, :no_sil_fr, :rev, :no_sil_bk, :no_sil, :trim, :fade ].each do |k|
    f[k.to_sym] = "/tmp/#{File.basename($0,'.*')}-#{k}.wav"
  end

  ampl = sox_query file, 'Maximum amplitude'
  
  sys "sox #{file} #{f[:vol_ad]} vol #{1/ampl}"

  sys "sox #{f[:vol_ad]} #{f[:no_sil_fr]} silence 1 0.02t 20%"

  sys "sox #{f[:no_sil_fr]} #{f[:rev]} reverse" 

  sys "sox #{f[:rev]} #{f[:no_sil_bk]} silence 1 0.02t 5%"

  sys "sox #{f[:no_sil_bk]} #{f[:no_sil]} reverse" 

  sys "sox #{f[:no_sil]} #{f[:trim]} trim 0 1" 

  sys "sox #{f[:trim]} #{f[:fade]} fade 0 -0 0.2" 

  system "ls -lrt #{f.values.join(' ')}" if $opts[:debug] > 1

  FileUtils.cp ( File.exist?(f[:fade]) ? f[:fade] : f[:trim] ), file

  unless $opts[:debug] > 1
    f.values.each do |f|
      FileUtils.rm f if File.exist?(f)
    end
  end

  sox_query file, 'Length'
end


def sox_query file, property
  ampl = %x(sox #{file} -n stat 2>&1).tap {|out| $? or fail "sox stat failed on #{file}: #{out}"}
           .lines.select {|line| line[property]}[0].split.last.to_f
end
