select
    0 as severity_key,
    'Unknown' as severity_level,
    'Not classified as Fatal, and persons killed or injured is missing'
        as severity_description,
    false as is_injury_or_fatal

union all

select
    1,
    'No Injury',
    'Persons killed = 0 and persons injured = 0',
    false

union all

select
    2,
    'Single Injury',
    'Persons killed = 0 and persons injured = 1',
    true

union all

select
    3,
    'Multiple Injuries',
    'Persons killed = 0 and persons injured >= 2',
    true

union all

select
    4,
    'Fatal',
    'Persons killed >= 1, regardless of persons injured',
    true