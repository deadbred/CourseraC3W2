class Place
	attr_accessor :id, :formatted_address, :location, :address_components

	def initialize(params)
		@id = params[:_id].to_s
		@formatted_address = params[:formatted_address]
		@location = Point.new(params[:geometry][:geolocation])
		@address_components = params[:address_components].map { |a| AddressComponent.new(a) } if !params[:address_components].nil?
	end

	def self.mongo_client
		Mongoid::Clients.default
	end

	def self.collection
		self.mongo_client['places']
	end

	def self.load_all(file)
		docs = JSON.parse(file.read)
		collection.insert_many(docs)
	end

	def self.find_by_short_name(short_name)
		collection.find( :'address_components.short_name' => short_name)
	end

	def self.to_places(places)
		places.map { |p| Place.new(p) }
	end

	def self.find(id)
		_id = BSON::ObjectId.from_string(id)
		place = collection.find(_id: _id).first

		return place.nil? ? nil : Place.new(place)
	end

	def self.all(offset=0, limit=nil)
		result = collection.find().skip(offset)
		result = result.limit(limit) if !limit.nil?
		result = to_places(result)
	end

	def destroy
		id = BSON::ObjectId.from_string(@id)
		self.class.collection.find(_id: id).delete_one
	end

	def self.get_address_components(sort=nil, offset=0, limit=nil)
		prototype = [ 
			{
				:$unwind => "$address_components"
			},
		    {
		    	:$project => { :_id => 1, :address_components => 1, :formatted_address => 1, :'geometry.geolocation' => 1}
		    }
		]

		
		prototype << {:$sort => sort} if !sort.nil?
		prototype << {:$skip => offset} if offset != 0
		prototype << {:$limit => limit} if !limit.nil?

		collection.find.aggregate(prototype)

	end

	def self.get_country_names
		prototype = [
			{
				:$unwind => "$address_components"
			}, 
		    {
		    	:$project => { :'address_components.long_name' => 1, :'address_components.types' => 1}
		    },
		    {
		    	:$match => { :'address_components.types' => "country"}
		    },
		    {
		    	:$group => { :_id => "$address_components.long_name"}
		    }
		]

		result = collection.find.aggregate(prototype)

		result.to_a.map { |h| h[:_id]}
	end

	def self.find_ids_by_country_code(country_code)
		prototype = [
			{
				:$match => { :'address_components.types' => "country", 
					         :'address_components.short_name' => country_code }
			},
		    {
		    	:$project => { :_id => 1}
		    }
		]

		result = collection.find.aggregate(prototype)

		result.to_a.map { |doc| doc[:_id].to_s}
	end

	def self.create_indexes
		collection.indexes.create_one( :'geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
	end

	def self.remove_indexes
		collection.indexes.drop_one('geometry.geolocation_2dsphere')
	end

	def self.near(point, max_meters = nil)
		collection.find( :'geometry.geolocation' =>
		    {
		    	:$near => {
		    		:$geometry => point.to_hash,
		    		:$maxDistance => max_meters
		    	}

			})
	end

	def near(max_meters = nil)
		result = self.class.near(@location, max_meters)
		self.class.to_places(result)
	end
end