require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] || :development)

CMD = "curl -H 'Authorization: Bearer 7WPTVWEMQBZOWT4HIHBNOI545DAGPLY5' 'https://api.wit.ai/message?v=20150322&q=%s'"

get '/version' do
  return 'v1'
end

get '/query/:query' do
  wit_json = Wit.text_query(params[:query].gsub('Defaults', '').gsub('Default', ''), ACCESS_TOKEN)
  #wit_json = %x(#{CMD % [params[:query]]})
  ap wit_json

  wit = JSON.parse(wit_json, { symbolize_names: true })[:outcomes][0]
  ap "Wit.ai output:"
  ap wit

  tables = {
    diseases: 'diseases',
    get_bill_count: 'bills',
    time_of_bill: 'bills',
    bill_status: 'bills',
    get_sabzi_price: 'mandi_prices'
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
    answer_template = "%s" if answer_template.nil? or answer_template.empty?
    answer_val = DB.query(sql_query).fetch_row[0]
    if answer_val.nil? or answer_val.empty?
      return "No Data found for #{entities[:disease][0][:value]}"
    end
    answer = answer_template % [answer_val]
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
    elsif status == 'pending'
      date_col == 'intro_date'
      condition2 = 'status = \'pending\''
    else
      halt 400
    end

    ministry = "1=1"
    if entities[:ministry]
      ministry = "ministry LIKE '%#{entities[:ministry][0][:value]}%'"
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
        WHERE #{condition} AND #{condition2} AND #{ministry}
      EOS
    puts sql_query

    answer_template = wit[:entities][:metric][0][:metadata]
    answer_template = "%s" if answer_template.nil? or answer_template.empty?
    answer = answer_template % [DB.query(sql_query).fetch_row[0]]
    ap answer

    ## bill status
  elsif intent == :bill_status
    bill_name = entities[:bill_name] && entities[:bill_name][0][:value]
    bill_name.sub! /\s+bill$/, ''
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

  ## sabzi price
  elsif intent == :get_sabzi_price
    commodity = entities[:commodity] && entities[:commodity][0][:value]
    state = entities[:state] && entities[:state][0][:value]
    puts commodity
    halt 400 if commodity.nil?
    sql_query = <<-EOS
      SELECT AVG(price)
      FROM #{tables[intent]}
      WHERE state = '#{state}' AND commodity LIKE '%#{commodity}%'
     EOS
    puts sql_query
    row = DB.query(sql_query).fetch_row
	if row.size == 0 || row[0].nil?
		answer = "No Data found for #{commodity} in #{state}"
		ap answer
		return answer
	end
	avg_price = ((row[0]).to_i)/100
    answer = "The price for 1 Kilogram of #{commodity} is #{avg_price} Rupees"
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
