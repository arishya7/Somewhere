extends RefCounted
## Every place on the map: where it is, what it's like, and the doors you can walk through.
## Street styles: shophouse, quay, city, park, village, beach. A "mall" venue opens an indoor street.

const COAST := [
	Vector2(103.605, 1.318), Vector2(103.620, 1.336), Vector2(103.640, 1.348), Vector2(103.655, 1.365), Vector2(103.675, 1.385),
	Vector2(103.690, 1.410), Vector2(103.705, 1.428), Vector2(103.722, 1.440), Vector2(103.745, 1.447), Vector2(103.765, 1.450),
	Vector2(103.785, 1.452), Vector2(103.800, 1.458), Vector2(103.815, 1.466), Vector2(103.830, 1.468), Vector2(103.845, 1.458),
	Vector2(103.858, 1.445), Vector2(103.870, 1.432), Vector2(103.885, 1.425), Vector2(103.900, 1.420), Vector2(103.915, 1.410),
	Vector2(103.935, 1.395), Vector2(103.955, 1.388), Vector2(103.975, 1.392), Vector2(103.995, 1.385), Vector2(104.015, 1.372),
	Vector2(104.030, 1.360), Vector2(104.025, 1.343), Vector2(104.005, 1.330), Vector2(103.985, 1.322), Vector2(103.960, 1.312),
	Vector2(103.935, 1.302), Vector2(103.910, 1.296), Vector2(103.890, 1.290), Vector2(103.875, 1.282), Vector2(103.862, 1.272),
	Vector2(103.848, 1.268), Vector2(103.835, 1.262), Vector2(103.820, 1.265), Vector2(103.805, 1.272), Vector2(103.790, 1.280),
	Vector2(103.770, 1.288), Vector2(103.750, 1.295), Vector2(103.730, 1.300), Vector2(103.712, 1.302), Vector2(103.695, 1.300),
	Vector2(103.675, 1.296), Vector2(103.655, 1.292), Vector2(103.635, 1.296), Vector2(103.615, 1.304),
]

const HOTSPOTS := [
	{"name": "Bras Basah", "ll": Vector2(103.851, 1.297), "cats": ["art", "culture"], "street": "city",
		"blurb": "Galleries, old bookshops and people who notice colour.",
		"venues": [["The Glass Gallery", "gallery"], ["Pages & Co.", "bookstore"], ["Studio Coffee", "cafe"]]},
	{"name": "Gillman Barracks", "ll": Vector2(103.804, 1.277), "cats": ["art"], "street": "village",
		"blurb": "Studios tucked into the trees. Bring curiosity.",
		"venues": [["Block 7 Gallery", "gallery"], ["Canopy Café", "cafe"], ["Print Room", "gallery"]]},
	{"name": "Esplanade", "ll": Vector2(103.856, 1.289), "cats": ["music", "culture"], "street": "quay",
		"blurb": "Free concerts by the water, most nights of the week.",
		"venues": [["Waterfront Bar", "bar"], ["Encore Records", "records"], ["Harbour Kitchen", "restaurant"]]},
	{"name": "Haji Lane", "ll": Vector2(103.862, 1.303), "cats": ["art", "music"], "street": "shophouse",
		"blurb": "Murals, vinyl and tiny bars that spill onto the street.",
		"venues": [["Side B Records", "records"], ["The Narrow Bar", "bar"], ["Second Act Thrift", "thrift"]]},
	{"name": "Bugis", "ll": Vector2(103.855, 1.300), "cats": ["food", "gaming"], "street": "shophouse",
		"blurb": "Thrift racks, late-night noodles and a mall that never sleeps.",
		"venues": [["Good Bones Thrift", "thrift"], ["Junction Mall", "mall"], ["Night Owl Noodle Bar", "restaurant"], ["Hidden Door Bar", "bar"]]},
	{"name": "Clarke Quay", "ll": Vector2(103.843, 1.289), "cats": ["nightlife", "music"], "street": "quay",
		"blurb": "Where the river gets loud after dark.",
		"venues": [["The Riverside Tap", "bar"], ["Ember & Oak", "restaurant"], ["Low Tide Club", "club"], ["Quayside Café", "cafe"]]},
	{"name": "Sports Hub", "ll": Vector2(103.875, 1.304), "cats": ["sports"], "street": "city",
		"blurb": "Courts, tracks and a crowd that cheers for strangers.",
		"venues": [["Vertical Climbing Wall", "studio"], ["Half Time Sports Bar", "bar"], ["Refuel Café", "cafe"]]},
	{"name": "East Coast Park", "ll": Vector2(103.930, 1.303), "cats": ["sports", "outdoors"], "street": "beach",
		"blurb": "Sea breeze, bikes and long sunset runs.",
		"venues": [["Seaside Shack", "cafe"], ["Breakwater Bar", "bar"], ["Grill on the Sand", "restaurant"]]},
	{"name": "MacRitchie", "ll": Vector2(103.822, 1.350), "cats": ["outdoors", "wellness"], "street": "park",
		"blurb": "Forest trails, treetop walks and quiet heads.",
		"venues": [["Trailhead Café", "cafe"], ["Canopy Yoga", "studio"]]},
	{"name": "Botanic Gardens", "ll": Vector2(103.815, 1.316), "cats": ["outdoors", "wellness"], "street": "park",
		"blurb": "Picnics, morning yoga and old, patient trees.",
		"venues": [["Orchid House Café", "cafe"], ["Lawn Yoga Studio", "studio"], ["Glasshouse Kitchen", "restaurant"]]},
	{"name": "Sentosa", "ll": Vector2(103.830, 1.250), "cats": ["outdoors", "nightlife"], "street": "beach",
		"blurb": "Beach clubs, sunsets and salt in your hair.",
		"venues": [["Tidal Beach Club", "club"], ["Sunset Shack", "bar"], ["Driftwood Grill", "restaurant"]]},
	{"name": "Tiong Bahru", "ll": Vector2(103.830, 1.284), "cats": ["food", "culture"], "street": "shophouse",
		"blurb": "Bakeries, bookshops and slow Sunday mornings.",
		"venues": [["Rise Bakery", "cafe"], ["Little Bookroom", "bookstore"], ["Courtyard Kitchen", "restaurant"]]},
	{"name": "Katong", "ll": Vector2(103.903, 1.306), "cats": ["food"], "street": "shophouse",
		"blurb": "Colourful shophouses and long, lazy lunches.",
		"venues": [["Parkway Mall", "mall"], ["Joo Chiat Kitchen", "restaurant"], ["Kopi & Crumb", "cafe"], ["Tile House Bar", "bar"]]},
	{"name": "Dempsey", "ll": Vector2(103.810, 1.303), "cats": ["food", "nightlife"], "street": "village",
		"blurb": "Wine, candlelight and dinners that run late.",
		"venues": [["The Cellar Door", "bar"], ["Long Table", "restaurant"], ["Greenhouse Café", "cafe"]]},
	{"name": "Holland Village", "ll": Vector2(103.795, 1.312), "cats": ["food", "nightlife"], "street": "village",
		"blurb": "Patio tables and conversations that drift.",
		"venues": [["The Local Quiz House", "bar"], ["Lamplight Bistro", "restaurant"], ["Holland Books", "bookstore"]]},
	{"name": "one-north", "ll": Vector2(103.788, 1.298), "cats": ["gaming", "culture"], "street": "city",
		"blurb": "Builders, gamers and people who make things.",
		"venues": [["Pixel Arcade", "arcade"], ["Commit Coffee", "cafe"], ["Board Game Lab", "arcade"]]},
	{"name": "Orchard", "ll": Vector2(103.833, 1.304), "cats": ["nightlife", "gaming"], "street": "city",
		"blurb": "Arcades, rooftops and late-night everything.",
		"venues": [["Orchard Galleria", "mall"], ["Skyline Rooftop Bar", "bar"], ["Neon Arcade", "arcade"]]},
	{"name": "Jurong Lake Gardens", "ll": Vector2(103.729, 1.338), "cats": ["outdoors", "wellness"], "street": "park",
		"blurb": "Wide lawns, still water, room to breathe.",
		"venues": [["Lakeside Café", "cafe"], ["Still Water Studio", "studio"]]},
	{"name": "Punggol Waterway", "ll": Vector2(103.906, 1.408), "cats": ["outdoors", "sports"], "street": "park",
		"blurb": "Boardwalks and bike loops at golden hour.",
		"venues": [["Boardwalk Café", "cafe"], ["Waterway Kitchen", "restaurant"]]},
	{"name": "Changi Village", "ll": Vector2(103.988, 1.388), "cats": ["food", "outdoors"], "street": "village",
		"blurb": "Planes overhead, ferries out, easy evenings.",
		"venues": [["Jetty Kitchen", "restaurant"], ["Ferry Point Café", "cafe"], ["Runway Bar", "bar"]]},
	{"name": "Woodlands Waterfront", "ll": Vector2(103.780, 1.451), "cats": ["outdoors", "wellness"], "street": "park",
		"blurb": "Watch the lights come on across the strait.",
		"venues": [["Strait View Café", "cafe"], ["Pier Yoga", "studio"]]},
]

## Shops inside a mall, keyed by the mall's name.
const MALL_SHOPS := {
	"Parkway Mall": [["Rewind Thrift", "thrift"], ["Paper Lantern Books", "bookstore"], ["Level 3 Arcade", "arcade"], ["Food Hall Café", "cafe"]],
	"Junction Mall": [["Loop Vintage", "thrift"], ["Game Room", "arcade"], ["Blue Note Records", "records"], ["Dumpling Bar", "restaurant"]],
	"Orchard Galleria": [["Atelier Resale", "thrift"], ["The Reading Room", "bookstore"], ["Glow Arcade", "arcade"], ["Galleria Wine Bar", "bar"]],
}

const VENUE_LABELS := {
	"bar": "Bar", "restaurant": "Restaurant", "cafe": "Café", "mall": "Mall", "thrift": "Thrift store",
	"gallery": "Gallery", "bookstore": "Bookshop", "records": "Record store", "arcade": "Arcade",
	"studio": "Studio", "club": "Club",
}

## What's happening inside, by venue type.
const VENUE_MOOD := {
	"bar": "Trivia night is on. Teams are forming.",
	"restaurant": "Candles on every table. Someone's celebrating.",
	"cafe": "The low hum of laptops and good coffee.",
	"thrift": "Racks of other people's stories.",
	"gallery": "A new show opened tonight.",
	"bookstore": "Quiet, except for pages turning.",
	"records": "Someone's playing a record nobody recognises.",
	"arcade": "Neon, high scores and friendly rivalries.",
	"studio": "Mats out, phones away.",
	"club": "The DJ is just warming up.",
}


static func find(name: String) -> Dictionary:
	for h in HOTSPOTS:
		if h.name == name:
			return h
	return {}
