class Place
	attr_accessor :id, :formatted_address, :location, :address_components

	def initialize(params)
		@id = params[:_id].to_s
		@formatted_address = params[:formatted_address]
		@location = Point.new(params[:geometry][:geolocation])
		@address_components = params[:address_components].map { |a| AddressComponent.new(a) } 
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
end