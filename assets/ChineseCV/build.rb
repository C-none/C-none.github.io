# frozen_string_literal: true

require "erb"
require "fileutils"
require "open3"
require "optparse"
require "pathname"
require "yaml"

CV_DIR = Pathname(__dir__).expand_path
DATA_PATH = CV_DIR.join("resume.yml")
TEMPLATE_PATH = CV_DIR.join("resume.tex.erb")
BUILD_DIR = CV_DIR.join(".build")
LANGUAGES = %w[zh en].freeze
DATE_PATTERN = /\A\d{4}(?:-\d{2})?\z/

class ResumeError < StandardError; end

module ResumeTools
  module_function

  def command(name)
    override = ENV[name.upcase]
    return override unless override.nil? || override.empty?

    if Gem.win_platform? && %w[pdfinfo pdftotext].include?(name)
      scoop_tool = Pathname(Dir.home).join("scoop", "apps", "poppler", "current", "bin", "#{name}.exe")
      return scoop_tool.to_s if scoop_tool.file?
    end

    name
  end
end

class ResumeValidator
  def initialize(resume)
    @resume = resume
    @ids = {}
  end

  def validate!
    hash!(@resume, "resume")
    error("version", "must be 1") unless @resume["version"] == 1
    validate_profile
    validate_education
    validate_entries("experience", bullets: true)
    validate_publications
    validate_entries("projects", bullets: true, dates: false)
    validate_awards
    validate_skills
    true
  end

  private

  def validate_profile
    profile = hash!(@resume["profile"], "profile")
    localized!(profile["name"], "profile.name")
    string!(profile["email"], "profile.email")
    string!(profile["website"], "profile.website")
    string!(profile["wechat_id"], "profile.wechat_id", prose: true)
    error("profile.email", "is not a valid email address") unless profile["email"].match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
    error("profile.website", "must be an http(s) URL") unless profile["website"].match?(%r{\Ahttps?://\S+\z})
  end

  def validate_education
    entries!("education").each_with_index do |entry, index|
      path = "education[#{index}]"
      id!(entry, path)
      %w[institution field degree].each { |field| localized!(entry[field], "#{path}.#{field}") }
      date!(entry["start"], "#{path}.start", month_required: true)
      date!(entry["end"], "#{path}.end", month_required: true)
    end
  end

  def validate_entries(section, bullets:, dates: true)
    entries!(section).each_with_index do |entry, index|
      path = "#{section}[#{index}]"
      id!(entry, path)
      if section == "experience"
        localized!(entry["company"], "#{path}.company")
        localized!(entry["position"], "#{path}.position")
      else
        localized!(entry["title"], "#{path}.title")
      end
      if dates
        date!(entry["start"], "#{path}.start", month_required: true)
        date!(entry["end"], "#{path}.end", month_required: true)
      end
      bullets!(entry["bullets"], "#{path}.bullets") if bullets
    end
  end

  def validate_publications
    entries!("publications").each_with_index do |entry, index|
      path = "publications[#{index}]"
      id!(entry, path)
      localized!(entry["title"], "#{path}.title")
      localized!(entry["venue"], "#{path}.venue")
      date!(entry["date"], "#{path}.date", month_required: true)
      bullets!(entry["bullets"], "#{path}.bullets")
      authors = array!(entry["authors"], "#{path}.authors", nonempty: true)
      authors.each_with_index do |author, author_index|
        author_path = "#{path}.authors[#{author_index}]"
        author = hash!(author, author_path)
        string!(author["name"], "#{author_path}.name", prose: true)
        error("#{author_path}.is_self", "must be true or false") unless [true, false].include?(author["is_self"])
      end
      error("#{path}.authors", "must mark exactly one author as self") unless authors.count { |author| author["is_self"] } == 1
    end
  end

  def validate_awards
    entries!("awards").each_with_index do |entry, index|
      path = "awards[#{index}]"
      id!(entry, path)
      localized!(entry["title"], "#{path}.title")
      dates = array!(entry["dates"], "#{path}.dates", nonempty: true)
      dates.each_with_index { |date, date_index| date!(date, "#{path}.dates[#{date_index}]") }
    end
  end

  def validate_skills
    entries!("skills").each_with_index do |entry, index|
      path = "skills[#{index}]"
      id!(entry, path)
      localized!(entry["label"], "#{path}.label")
      values = array!(entry["values"], "#{path}.values", nonempty: true)
      values.each_with_index do |value, value_index|
        value_path = "#{path}.values[#{value_index}]"
        value.is_a?(Hash) ? localized!(value, value_path) : string!(value, value_path, prose: true)
      end
    end
  end

  def entries!(section)
    array!(@resume[section], section, nonempty: true).map.with_index { |entry, index| hash!(entry, "#{section}[#{index}]") }
  end

  def bullets!(value, path)
    array!(value, path, nonempty: true).each_with_index { |bullet, index| localized!(bullet, "#{path}[#{index}]") }
  end

  def localized!(value, path)
    value = hash!(value, path)
    error(path, "must contain exactly zh and en") unless value.keys.sort == LANGUAGES.sort
    LANGUAGES.each { |language| string!(value[language], "#{path}.#{language}", prose: true) }
  end

  def id!(entry, path)
    id = string!(entry["id"], "#{path}.id")
    error("#{path}.id", "duplicates #{@ids[id]}") if @ids.key?(id)
    @ids[id] = "#{path}.id"
  end

  def date!(value, path, month_required: false)
    value = string!(value, path)
    error(path, "must be a quoted YYYY or YYYY-MM string") unless value.match?(DATE_PATTERN)
    parts = value.split("-")
    error(path, "must include a month") if month_required && parts.length != 2
    error(path, "contains an invalid month") if parts[1] && !(1..12).cover?(parts[1].to_i)
    value
  end

  def string!(value, path, prose: false)
    error(path, "must be a non-empty string") unless value.is_a?(String) && !value.strip.empty?
    error(path, "must not contain raw LaTeX commands") if prose && value.include?("\\")
    value
  end

  def hash!(value, path)
    error(path, "must be a mapping") unless value.is_a?(Hash)
    value
  end

  def array!(value, path, nonempty: false)
    error(path, "must be a list") unless value.is_a?(Array)
    error(path, "must not be empty") if nonempty && value.empty?
    value
  end

  def error(path, message)
    raise ResumeError, "#{path}: #{message}"
  end
end

class ResumeTemplate
  HEADINGS = {
    zh: { education: "教育背景", experience: "职业经历", publications: "发表论文", projects: "项目作品", awards: "奖项荣誉", skills: "技术能力" },
    en: { education: "Education", experience: "Professional Experience", publications: "Publications", projects: "Projects", awards: "Honors and Awards", skills: "Technical Skills" }
  }.freeze
  MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
  LATEX_ESCAPES = {
    "\\" => "\\textbackslash{}", "{" => "\\{", "}" => "\\}", "$" => "\\$", "&" => "\\&",
    "#" => "\\#", "_" => "\\_", "%" => "\\%", "~" => "\\textasciitilde{}", "^" => "\\textasciicircum{}"
  }.freeze

  attr_reader :resume, :profile

  def initialize(resume, language)
    @resume = resume
    @language = language.to_sym
    @profile = resume.fetch("profile")
  end

  def render(template)
    ERB.new(template, trim_mode: "-").result(binding)
  end

  def chinese?
    @language == :zh
  end

  def localize(value)
    latex_escape(value.fetch(@language.to_s))
  end

  def heading(key)
    HEADINGS.fetch(@language).fetch(key)
  end

  def education_title(entry)
    institution = localize(entry.fetch("institution"))
    field = localize(entry.fetch("field"))
    degree = localize(entry.fetch("degree"))
    return "\\textbf{#{institution}}，#{field}，\\textit{#{degree}}" if chinese?

    "\\textbf{#{institution}}, \\textit{#{degree}} in #{field}"
  end

  def experience_title(entry)
    separator = chinese? ? "，" : ", "
    "#{localize(entry.fetch("company"))}#{separator}#{localize(entry.fetch("position"))}"
  end

  def publication_authors(authors)
    authors.map do |author|
      name = latex_escape(author.fetch("name"))
      author.fetch("is_self") ? "\\textbf{#{name}}" : name
    end.join(", ")
  end

  def skill_values(values)
    values.map { |value| value.is_a?(Hash) ? localize(value) : latex_escape(value) }.join(", ")
  end

  def format_date(value)
    year, month = value.split("-").map(&:to_i)
    return year.to_s unless month
    chinese? ? "#{year}.#{month}" : "#{MONTHS.fetch(month - 1)} #{year}"
  end

  def date_range(entry)
    "#{format_date(entry.fetch("start"))}--#{format_date(entry.fetch("end"))}"
  end

  def format_dates(values)
    values.map { |value| format_date(value) }.join(", ")
  end

  def email_link(email)
    escaped = latex_escape(email)
    "\\href{mailto:#{escaped}}{#{escaped}}"
  end

  def hyperlink(url, label)
    "\\href{#{latex_escape(url)}}{#{latex_escape(label)}}"
  end

  def website_label
    profile.fetch("website").sub(%r{\Ahttps?://}, "").sub(%r{/\z}, "")
  end

  def wechat_contact
    label = chinese? ? "微信" : "WeChat"
    "#{label}: #{latex_escape(profile.fetch("wechat_id"))}"
  end

  private

  def latex_escape(value)
    value.to_s.gsub(/[\\{}$&#_%~^]/) { |character| LATEX_ESCAPES.fetch(character) }
  end
end

class ResumeBuilder
  ANCHORS = {
    "zh" => ["龙胡志远", "香港大学", "网易互娱", "腾讯", "SRSSIS", "huzhiyuan.long@outlook.com", "c-none.github.io", "ReSTIR"],
    "en" => ["Huzhiyuan Long", "The University of Hong Kong", "NetEase Games", "LIGHTSPEED STUDIOS", "SRSSIS", "huzhiyuan.long@outlook.com", "c-none.github.io", "ReSTIR"]
  }.freeze

  def initialize(resume, template)
    @resume = resume
    @template = template
  end

  def build!(languages)
    FileUtils.mkdir_p(BUILD_DIR)
    candidates = languages.to_h { |language| [language, build_candidate!(language)] }
    candidates.each { |language, candidate| publish!(candidate, CV_DIR.join("lhzy_resume_#{language}.pdf")) }
  end

  private

  def build_candidate!(language)
    language_dir = BUILD_DIR.join(language)
    FileUtils.rm_rf(language_dir)
    FileUtils.mkdir_p(language_dir)
    job_name = "lhzy_resume_#{language}"
    tex_path = language_dir.join("#{job_name}.tex")
    tex_path.write(ResumeTemplate.new(@resume, language).render(@template), encoding: "UTF-8")

    command = [ResumeTools.command("xelatex"), "-interaction=nonstopmode", "-halt-on-error", "-file-line-error", "-output-directory=#{language_dir}", "-jobname=#{job_name}", tex_path.to_s]
    2.times do |pass|
      stdout, stderr, status = Dir.chdir(CV_DIR) { Open3.capture3(*command) }
      language_dir.join("xelatex.pass#{pass + 1}.stdout.log").write(stdout, encoding: "UTF-8")
      language_dir.join("xelatex.pass#{pass + 1}.stderr.log").write(stderr, encoding: "UTF-8")
      raise ResumeError, "#{language}: XeLaTeX pass #{pass + 1} failed (see #{language_dir})" unless status.success?
    end

    log = language_dir.join("#{job_name}.log").read(encoding: "UTF-8", invalid: :replace, undef: :replace)
    raise ResumeError, "#{language}: PDF contains missing glyphs" if log.include?("Missing character:")
    raise ResumeError, "#{language}: layout contains an overfull box" if log.match?(/Overfull \\[hv]box/)

    pdf_path = language_dir.join("#{job_name}.pdf")
    validate_pdf!(pdf_path, language)
    pdf_path
  end

  def validate_pdf!(pdf_path, language)
    raise ResumeError, "#{language}: XeLaTeX did not create a PDF" unless pdf_path.file?
    info, info_error, info_status = Open3.capture3(ResumeTools.command("pdfinfo"), pdf_path.to_s)
    raise ResumeError, "#{language}: pdfinfo failed: #{info_error.strip}" unless info_status.success?
    raise ResumeError, "#{language}: PDF must contain exactly one page" unless info.match?(/^Pages:\s+1\s*$/)
    size_match = info.match(/^Page size:\s+([\d.]+) x ([\d.]+) pts/)
    unless size_match && (size_match[1].to_f - 595.28).abs < 1 && (size_match[2].to_f - 841.89).abs < 1
      raise ResumeError, "#{language}: PDF must use A4 page size"
    end

    text, text_error, text_status = Open3.capture3(ResumeTools.command("pdftotext"), "-enc", "UTF-8", "-layout", pdf_path.to_s, "-")
    raise ResumeError, "#{language}: pdftotext failed: #{text_error.strip}" unless text_status.success?
    text = text.force_encoding("UTF-8")
    raise ResumeError, "#{language}: extracted PDF text is not valid UTF-8" unless text.valid_encoding?
    missing = ANCHORS.fetch(language).reject { |anchor| text.include?(anchor) }
    raise ResumeError, "#{language}: PDF text is missing #{missing.join(", ")}" unless missing.empty?
  end

  def publish!(candidate, target)
    staged = target.dirname.join(".#{target.basename}.#{Process.pid}.tmp")
    FileUtils.cp(candidate, staged)
    if Gem.win_platform?
      replace_on_windows!(staged, target)
    else
      File.rename(staged, target)
    end
  ensure
    FileUtils.rm_f(staged) if staged
  end

  def replace_on_windows!(source, target)
    require "fiddle/import"
    kernel = Module.new do
      extend Fiddle::Importer
      dlload "kernel32.dll"
      extern "int MoveFileExW(void*, void*, unsigned long)"
    end
    wide = lambda { |path| (path.to_s.encode(Encoding::UTF_16LE) + "\0".encode(Encoding::UTF_16LE)) }
    flags = 0x1 | 0x8 # MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH
    result = kernel.MoveFileExW(wide.call(source), wide.call(target), flags)
    raise ResumeError, "could not publish #{target}" if result.zero?
  end
end

def main(arguments = ARGV)
  options = { language: "all", validate_only: false }
  OptionParser.new do |parser|
    parser.banner = "Usage: ruby build.rb [--lang zh|en|all] [--validate-only]"
    parser.on("--lang LANGUAGE", LANGUAGES + ["all"], "build zh, en, or all") { |value| options[:language] = value }
    parser.on("--validate-only", "validate resume.yml without building PDFs") { options[:validate_only] = true }
  end.parse!(arguments)

  yaml = DATA_PATH.read(encoding: "UTF-8")
  resume = YAML.safe_load(yaml, permitted_classes: [], permitted_symbols: [], aliases: false)
  ResumeValidator.new(resume).validate!
  puts "Validated #{DATA_PATH.relative_path_from(CV_DIR.parent.parent)}"
  unless options[:validate_only]
    languages = options[:language] == "all" ? LANGUAGES : [options[:language]]
    ResumeBuilder.new(resume, TEMPLATE_PATH.read(encoding: "UTF-8")).build!(languages)
    puts "Built #{languages.map { |language| "lhzy_resume_#{language}.pdf" }.join(" and ")}"
  end
  0
rescue OptionParser::ParseError, Psych::Exception, ResumeError, Errno::ENOENT => error
  warn "resume build failed: #{error.message}"
  1
end

exit main if $PROGRAM_NAME == __FILE__
