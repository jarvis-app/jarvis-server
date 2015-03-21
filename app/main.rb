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

  table = wit[:intent]
  output_col = wit[:entities][:metric][0][:value]
  entities = wit[:entities]
  ap table
  ap output_col

  answer = 'hello!'
  if table == 'diseases'
    disease = "disease = '#{entities[:disease][0][:value]}'"
    state = "1=1"
    if entities[:state] && entities[:state][0][:value] != 'India'
      state = "state = '#{entities[:state][0][:value]}'"
    end
    year = "1=1"
    if entities[:datetime]
      year = "year = #{entities[:datetime][0][:value][/^\d+/].to_i}"
    end
    sql_query = <<-EOS
        SELECT SUM(#{output_col})
        FROM #{table}
        WHERE #{disease} AND #{state} AND #{year}
      EOS
    puts sql_query
    answer = DB.query(sql_query).fetch_row[0]
    ap answer
  end

  return answer
end

get '/' do
  return 'hello!'
end
