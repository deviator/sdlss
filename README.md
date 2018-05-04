## SDLang struct serialize 
[![Build Status](https://travis-ci.org/deviator/sdlss.svg?branch=master)](https://travis-ci.org/deviator/sdlss)
[![Build status](https://ci.appveyor.com/api/projects/status/u20o6l7v7x33hj9r/branch/master?svg=true)](https://ci.appveyor.com/project/deviator/sdlss/branch/master)
[![codecov](https://codecov.io/gh/deviator/sdlss/branch/master/graph/badge.svg)](https://codecov.io/gh/deviator/sdlss)
[![Dub](https://img.shields.io/dub/v/sdlss.svg)](http://code.dlang.org/packages/sdlss)
[![Downloads](https://img.shields.io/dub/dt/sdlss.svg)](http://code.dlang.org/packages/sdlss)
[![License](https://img.shields.io/dub/l/sdlss.svg)](http://code.dlang.org/packages/sdlss)

### Rules

* use bool, string, int, double, Date, DateTimeFrac,
    Duration, ubyte[], structs and they arrays for fields type
* enum converts to strings
* byte, ubyte, short, ushort converts to int
* float and real converts to double
* attributes not used (see TODO)
* no value in sdl set default struct field value
* empty value in sdl for arrays set struct field to []
* structs arrays define as duplicate tags
* simple type arrays space separated values (ex "foo 1 2 3" -> int[] foo = [1,2,3])
* if multiple tag defined for settings fields used last

### Example

`app.d`
```d
struct Settings
{
    struct Com
    {
        string dev = "/dev/ttyUSB0";
        int baudrate = 19200;
        string mode = "8N1";
    }

    Com com;

    struct Data
    {
        string name;
        int[] signal;
    }

    Data[] data = [Data("first", [1, 1, 2, 3, 5])];
}

auto sets = readStruct!Settings("settings.sdl");
```

`settings.sdl`
```sdl
com {
	dev "/dev/ttyUSB0"
	baudrate 19200
	mode "8N1"
}
data {
	name "first"
	signal 1 1 2 3 5
}
data {
    name "second"
    signal 1 4 8
}
```

see [example](example)
