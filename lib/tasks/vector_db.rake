namespace :vector_db do
  desc 'Initialize and seed the vector database'
  task :initialize_and_seed => :environment do
    InitializeAndSeedVectorDb.new.run
  end
end