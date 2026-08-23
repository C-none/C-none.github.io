# frozen_string_literal: true

require "stringio"
require "tempfile"
require "yaml"
require_relative "build"

resume = YAML.safe_load(DATA_PATH.read(encoding: "UTF-8"), permitted_classes: [], permitted_symbols: [], aliases: false)
tests = []

tests << ["current resume is valid", lambda do
  raise "validator returned false" unless ResumeValidator.new(Marshal.load(Marshal.dump(resume))).validate!
end]

tests << ["English education uses degree-in-field wording", lambda do
  template = ResumeTemplate.new(resume, "en")
  title = template.education_title(resume.fetch("education")[1])
  expected = "\\textbf{Tongji University}, \\textit{B.Eng.} in Software Engineering"
  raise "unexpected title: #{title}" unless title == expected
end]

tests << ["localized date ranges use compact en dashes", lambda do
  entry = resume.fetch("experience")[1]
  raise "unexpected Chinese date range" unless ResumeTemplate.new(resume, "zh").date_range(entry) == "2025.5--2025.8"
  raise "unexpected English date range" unless ResumeTemplate.new(resume, "en").date_range(entry) == "May 2025--Aug 2025"
end]

tests << ["missing translation reports its path", lambda do
  data = Marshal.load(Marshal.dump(resume))
  data.fetch("education").first.fetch("degree").delete("en")
  begin
    ResumeValidator.new(data).validate!
    raise "validation unexpectedly succeeded"
  rescue ResumeError => error
    raise error unless error.message.start_with?("education[0].degree:")
  end
end]

tests << ["duplicate ID reports its path", lambda do
  data = Marshal.load(Marshal.dump(resume))
  education = data.fetch("education")
  education[1]["id"] = education[0].fetch("id")
  begin
    ResumeValidator.new(data).validate!
    raise "validation unexpectedly succeeded"
  rescue ResumeError => error
    raise error unless error.message.start_with?("education[1].id:")
  end
end]

tests << ["invalid date reports its path", lambda do
  data = Marshal.load(Marshal.dump(resume))
  data.fetch("education").first["start"] = "2025-13"
  begin
    ResumeValidator.new(data).validate!
    raise "validation unexpectedly succeeded"
  rescue ResumeError => error
    raise error unless error.message.start_with?("education[0].start:")
  end
end]

tests << ["empty bullet reports its path", lambda do
  data = Marshal.load(Marshal.dump(resume))
  data.fetch("experience").first.fetch("bullets").first["zh"] = ""
  begin
    ResumeValidator.new(data).validate!
    raise "validation unexpectedly succeeded"
  rescue ResumeError => error
    raise error unless error.message.start_with?("experience[0].bullets[0].zh:")
  end
end]

tests << ["raw LaTeX reports its path", lambda do
  data = Marshal.load(Marshal.dump(resume))
  data.fetch("experience").first.fetch("bullets").first["en"] = "\\textbf{not allowed}"
  begin
    ResumeValidator.new(data).validate!
    raise "validation unexpectedly succeeded"
  rescue ResumeError => error
    raise error unless error.message.start_with?("experience[0].bullets[0].en:")
  end
end]

tests << ["invalid data makes the CLI return nonzero", lambda do
  data = Marshal.load(Marshal.dump(resume))
  data.fetch("projects").first.fetch("title").delete("en")
  Tempfile.create(["invalid-resume", ".yml"]) do |file|
    file.write(YAML.dump(data))
    file.flush
    original_path = DATA_PATH
    original_stderr = $stderr
    stderr = StringIO.new
    Object.send(:remove_const, :DATA_PATH)
    Object.const_set(:DATA_PATH, Pathname(file.path))
    $stderr = stderr
    status = main(["--validate-only"])
    raise "CLI returned #{status}" unless status == 1
    raise "CLI did not report the YAML path" unless stderr.string.include?("projects[0].title")
  ensure
    $stderr = original_stderr
    Object.send(:remove_const, :DATA_PATH)
    Object.const_set(:DATA_PATH, original_path)
  end
end]

failures = []
tests.each do |name, test|
  test.call
  puts "PASS: #{name}"
rescue StandardError => error
  failures << [name, error]
  warn "FAIL: #{name}: #{error.message}"
end

if failures.empty?
  puts "#{tests.length} validation tests passed"
  exit 0
end

exit 1
