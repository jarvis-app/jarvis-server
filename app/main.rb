require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] || :development)

get '/version' do
  return 'v1'
end

get '/query/:query' do
  wit_json = Wit.text_query(params[:query].gsub('Defaults', '').gsub('Default', ''), ACCESS_TOKEN)
  ap wit_json

  wit = JSON.parse(wit_json, { symbolize_names: true })[:outcomes][0]
  ap "Wit.ai output:"
  ap wit

  tables = {
    diseases: 'diseases',
    get_bill_count: 'bills',
    time_of_bill: 'bills',
    bill_status: 'bills'
  }

  intent = wit[:intent].to_sym
  entities = wit[:entities]
  ap intent

  answer = 'hello!'

  ## diseases
  if intent == :diseases
    output_col = wit[:entities][:metric][0][:value]
    disease = "disease = '#{entities[:disease][0][:value]}'"
    state = "1=1"
    if entities[:state] && entities[:state][0][:value] != 'India'
      state = "state = '#{entities[:state][0][:value]}'"
    end
    year = "1=1"
    if entities[:datetime]
      if entities[:datetime][0][:type] == "value"
        year = "year = #{datetime_to_year(entities[:datetime][0][:value])}"
      elsif entities[:datetime][0][:type] == "interval"
        year = "year BETWEEN #{datetime_to_year(entities[:datetime][0][:from][:value])} AND #{datetime_to_year(entities[:datetime][0][:to][:value]) - 1}"
      else
        halt 400
      end
    end

    sql_query = <<-EOS
        SELECT SUM(#{output_col})
        FROM diseases
        WHERE #{disease} AND #{state} AND #{year}
      EOS
    puts sql_query

    answer_template = wit[:entities][:metric][0][:metadata]
    answer_template = "%s" if answer_template.empty?
    answer = answer_template % [DB.query(sql_query).fetch_row[0]]
    ap answer


  ## bill count
  elsif intent == :get_bill_count
    condition = '1=1'
    condition2 = '1=1'
    date_col = nil
    status = entities[:status] && entities[:status][0][:value]
    halt 400 if status.nil?
    if status == 'passed' || status == 'assented'
      house = entities[:assembly_name] && entities[:assembly_name][0][:value]
      if house == 'ls'
        date_col = 'ls_pass_date'
      elsif house == 'rs'
        date_col = 'rs_pass_date'
      else
        date_col = 'intro_date'
        condition2 = 'status IN (\'passed\', \'assented\')'
      end
    elsif status == 'introduced'
      date_col = 'intro_date'
    # elsif status == 'pending'
    #   date_col ==
    else
      halt 400
    end

    extract_year = "EXTRACT(YEAR FROM #{date_col})"

    if entities[:datetime]
      if entities[:datetime][0][:type] == "value"
        condition = "#{extract_year} = #{datetime_to_year(entities[:datetime][0][:value])}"
      elsif entities[:datetime][0][:type] == "interval"
        condition = "#{extract_year} BETWEEN #{datetime_to_year(entities[:datetime][0][:from][:value])} AND #{datetime_to_year(entities[:datetime][0][:to][:value]) - 1}"
      else
        halt 400
      end
    end

    sql_query = <<-EOS
        SELECT COUNT(*)
        FROM #{tables[intent]}
        WHERE #{condition} AND #{condition2}
      EOS
    puts sql_query

    answer_template = wit[:entities][:metric][0][:metadata]
    answer_template = "%s" if answer_template.empty?
    answer = answer_template % [DB.query(sql_query).fetch_row[0]]
    ap answer

    ## bill status
  elsif intent == :bill_status
    bill_name = entities[:bill_name] && entities[:bill_name][0][:value]
    halt 400 if bill_name.nil?
    sql_query = <<-EOS
        SELECT bill_title, status
        FROM #{tables[intent]}
        WHERE bill_title LIKE '%#{bill_name}%'
        ORDER BY intro_date DESC
        LIMIT 1
      EOS
    puts sql_query

    templates = {
      'passed' => '%s has been passed by Parliament',
      'assented' => '%s has been passed by Parliament',
      'lapsed' => '%s has lapsed',
      'pending' => '%s is pending in Parliament',
      'withdrawn' => '%s has been withdrawn from Parliament'
    }
    row = DB.query(sql_query).fetch_row
    title = row[0].strip
    status = row[1].strip
    answer = templates[status.downcase] % title
    ap answer

  else
    halt 400
  end

  return answer
end

get '/' do
  return 'hello!'
end


## HELPERS
helpers do
  def datetime_to_year(datetime)
    return datetime[/^\d+/].to_i
  end
end
