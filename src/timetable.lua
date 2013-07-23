local floor = math.floor
local function idiv ( n , d )
	return floor ( n / d )
end


local mon_lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
-- Number of days in year until start of month; not corrected for leap years
local months_to_days_cumulative = { 0 }
for i = 2, 12 do
	months_to_days_cumulative [ i ] = months_to_days_cumulative [ i-1 ] + mon_lengths [ i-1 ]
end

local function is_leap ( y )
	return (y % 4) == 0 and (y % 100) ~= 0 or (y % 400) == 0
end

local function year_length ( y )
	return is_leap ( y ) and 366 or 365
end

local function month_length ( m , y )
	if m == 2 then
		return is_leap ( y ) and 29 or 28
	else
		return mon_lengths [ m ]
	end
end

local function doomsday ( year )
	return ( 3 -- Tuesday
		- 1 + year + idiv ( year , 4 ) - idiv ( year , 100 ) + idiv ( year , 400 ) )
		% 7 + 1
end
local doomsday_cache = setmetatable ( { } , {
	__index = function ( cache , year )
		local d = doomsday ( year )
		cache [ year ] = d
		return d
	end ;
} )

local function day_of_year ( day , month , year )
	local yday = months_to_days_cumulative [ month ]
	if month > 2 and is_leap ( year ) then
		yday = yday + 1
	end
	return yday + day
end

local function day_of_week ( yday , year )
	return ( yday - doomsday_cache [ year ] - 1 ) % 7 + 1
end

local function increment ( tens , units , base )
	if units >= base then
		tens  = tens + idiv ( units , base )
		units = units % base
	elseif units < 0 then
		tens  = tens - 1 + idiv ( -units , base )
		units = base - ( -units % base )
	end
	return tens , units
end

local function unpack_tm ( tm )
	return assert ( tm.year  , "year required" ) ,
		assert ( tm.month , "month required" ) ,
		assert ( tm.day   , "day required" ) ,
		tm.hour or 12 ,
		tm.min  or 0 ,
		tm.sec  or 0
end

-- Modify parameters so they all fit within the "normal" range
local function normalise ( year , month , day , hour , min , sec )
	min  , sec  = increment ( min  , sec  , 60 ) -- TODO: consider leap seconds?
	hour , min  = increment ( hour , min  , 60 )
	day  , hour = increment ( day  , hour , 24 )

	while day <= 0 do
		year = year - 1
		day  = day + year_length ( year )
	end

	-- This could potentially be slow if `day` is very large
	while true do
		local i = month_length ( month , year )
		if day <= i then break end
		day = day - i
		month = month + 1
	end

	-- Lua months start from 1, need -1 and +1 around this increment
	year , month = increment ( year , month - 1 , 12 )
	month = month + 1

	return year , month , day , hour , min , sec
end

local function timestamp ( year , month , day , hour , min , sec )
	return 60*60*24*(
			year * year_length ( year )
			+ month * month_length ( month , year )
			+ day
		)
		+ hour  * (60*60)
		+ min   * 60
		+ sec
end


local timetable_methods = { }

function timetable_methods:normalise ( )
	local year , month , day
	year , month , day , self.hour , self.min , self.sec = normalise ( unpack_tm ( self ) )

	self.day   = day
	self.month = month
	self.year  = year

	local yday = day_of_year ( day , month , year )
	local wday = day_of_week ( yday , year )

	self.yday = yday
	self.wday = wday

	return self
end
timetable_methods.normalize = timetable_methods.normalise -- American English

function timetable_methods:timestamp ( )
	return timestamp ( unpack_tm ( self ) )
end

local timetable_mt = {
	__index    = timetable_methods ;
}

local function cast_timetable ( tm )
	return setmetatable ( tm , timetable_mt )
end

local function new_timetable ( year , month , day , hour , min , sec )
	return cast_timetable {
		year  = year ;
		month = month ;
		day   = day ;
		hour  = hour ;
		min   = min ;
		sec   = sec ;
	}
end

return {
	doomsday  = doomsday ;
	normalise = normalise ;
	timestamp = timestamp ;

	new = new_timetable ;
	cast = cast_timetable ;
	timetable_mt = timetable_mt ;
}