local Topics = require "scripts.topics"
return {
    Unknown = Color(0.5, 0.5, 0.5, 1.0),

    [Topics.Love] =      Color(250.0 / 255.0, 20.0 / 255.0,     15.0/255.0, 1.0), -- red
    [Topics.Humility] =  Color(221.0 / 255.0, 187.0 / 255.0,    2.0 / 255.0, 1.0), -- yellow (gold?)
    [Topics.Purity] =    Color(91.0/255.0,    179.0 / 255.0,    19.0 / 255.0, 1.0), -- green
    [Topics.Honesty] =   Color(0,             144.0 / 255.0,    255.0 / 255.0, 1.0), --blue 
    [Topics.Faith] =     Color(176.0/255.0,   0.0 /255.0,       227.0 / 255.0, 1.0), -- purple
    [Topics.GoodWorks] = Color(227.0/255.0,   140.0 /255.0,     3.0 / 255.0, 1.0)  -- orange

    --[Topics.Fear] = Color(217.0/ 255.0, 207.0 / 255.0,20.0 / 255.0,1.0)
}