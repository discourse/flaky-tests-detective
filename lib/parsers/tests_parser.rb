# frozen_string_literal: true

class TestsParser
  def attatch_to_report(report, archive, commit_hash)
    raise NotImplemented
  end

  def errors(state, archive, commit_hash)
    raise NotImplemented
  end

  def slowest_tests(state, archive, commit_hash)
    raise NotImplemented
  end

  protected

  def find_test(state, key)
    return { occurances: 1 } unless state[:slowest_tests].key?(key)

    state[:slowest_tests][key].tap { |ss| ss[:occurances] += 1 }
  end

  def record_time(test, key, seconds)
    test[:average] = calculate_average_time(test, key, seconds)
    test[:worst] = seconds if test[:worst].to_f < seconds
    test[:best] = seconds if test[:best].to_f.zero? || test[:best].to_f > seconds
  end

  def calculate_average_time(test, test_key, current_seconds)
    existing_seconds = test[:average]
    return current_seconds unless existing_seconds

    occurances = test[:occurances]
    existing_seconds + ((current_seconds - existing_seconds) / occurances)
  end

  def build_test_key(raw)
    raise NotImplemented
  end

  def strip_line(line)
    line.strip.gsub(/\e\[([;\d]+)?m/, '')
  end

  def test_template(commit_hash)
    { failures: 1, appeared_on: commit_hash, last_seen: commit_hash }
  end
end
