/++ SDLang struct serialize
 +/
module sdlss;

public import sdlang;

import std.meta;
import std.traits;
import std.range : ElementType;
import std.datetime;
import std.conv;
import std.string : toLower;

///
T readStruct(T)(string fname)
{ return buildStruct!T(fname.parseFile); }

///
void readStruct(T)(ref T st, string fname)
{ fillStruct(st, fname.parseFile); }

///
void writeStruct(T)(auto ref const T st, string fname)
{
    import std.file : write;
    fname.write(structToSDLDocument(st));
}

///
string structToSDLDocument(T)(auto ref const T st)
{ return buildTag(st).toSDLDocument; }

///
T buildStruct(T)(Tag tag) if (is(T==struct))
{
    T ret;
    fillStruct(ret, tag);
    return ret;
}

bool isUserStruct(T)() @property
{
    return is(T == struct) &&
           !is(T == Date) &&
           !is(T == SysTime) &&
           !is(T == DateTime) &&
           !is(T == DateTimeFrac) &&
           !is(T == DateTimeFracUnknownZone) &&
           !is(T == Duration);
}

bool isSerializableArray(T)() @property
{
    return isArray!T &&
           !isSomeString!T &&
           !(is(Unqual!T == char[])) &&
           !(is(Unqual!T : const(char)[])) &&
           !(is(Unqual!T == ubyte[])) &&
           !(is(Unqual!T : const(ubyte)[]));
}

alias FloatingType = double;

template maskType(T)
{
    static if (is(T == enum))
        alias maskType = string;
    else static if (is(T == byte) ||
                    is(T == ubyte) ||
                    is(T == short) ||
                    is(T == ushort) ||
                    is(T == uint)
    )
        alias maskType = int;
    else static if (is(T == ulong))
        alias maskType = long;
    else static if(isFloatingPoint!T)
        alias maskType = FloatingType;
    else alias maskType = T;
}

bool isSerializableDynamicArray(T)() @property
{ return isDynamicArray!T && isSerializableArray!T; }

///
void fillStruct(OT)(ref OT st, Tag[] tags...)
{
    static void getValue(X, OX)(ref OX f, auto ref const Value val)
    {
        static if (isFloatingPoint!OX)
        {
            if (val.type == typeid(string) && val.get!string.idup.toLower == "nan")
                f = OX.nan;
            else if (val.type == typeid(X))
                f = val.get!X.to!OX;
            else if (val.type == typeid(int))
                f = val.get!long.to!OX;
            else if (val.type == typeid(long))
                f = val.get!long.to!OX;
            else { /+ TODO: warning +/ }
        }
        else f = val.get!X.to!OX;
    }

    import std.array;

    alias T = maskType!OT;

    static if (isArray!T)
    {
        alias OElem = Unqual!(ElementType!T);
        alias Elem = maskType!(Unqual!(ElementType!T));
    }

    static if (isSerializableDynamicArray!T) st = [];

    if (tags.length == 0) return;

    static if (isUserStruct!T)
    {
        if (tags.length > 1) { /+ TODO warning +/ }
        auto tag = tags[$-1]; // get last tag
        foreach (i, ref f; st.tupleof)
        {
            enum name = __traits(identifier, st.tupleof[i]);
            static if (name != "this") // const(void)* context ptr
            {
                if (name in tag.tags)
                    fillStruct(f, tag.tags[name].array);
                else { /+ TODO something +/ }
            }
        }
    }
    else static if (isSerializableArray!T)
    {
        static if (isUserStruct!Elem)
            foreach (i, ct; tags)
            {
                if (ct.tags.length)
                {
                    static if (isStaticArray!T)
                    {
                        if (i >= st.length) /+ TODO warning +/ break;
                        fillStruct(ct, st[i]);
                    }
                    else st ~= buildStruct!Elem(ct);
                }
            }
        else
        {
            if (tags.length > 1) { /+ TODO warning +/ }
            foreach (i, v; tags[$-1].values) // get last tag
            {
                static if (isStaticArray!T)
                {
                    if (i >= st.length) /+ TODO warning +/ break;
                    getValue!(Elem, OElem)(st[i], v);
                }
                else
                {
                    OElem tmp;
                    getValue!(Elem, OElem)(tmp, v);
                    st ~= tmp;
                }
            }
        }
    }
    else
    {
        if (tags.length > 1) { /+ TODO warning +/ }
        if (tags[$-1].values.length == 0) return; // no values (TODO warning?)
        getValue!(T, OT)(st, tags[$-1].values[0]);
    }
}

unittest
{
    static struct Test
    {
        string str = "okda";
    }

    enum s1 = `str "hello"`;
    enum s2 = `abc "hello"`;

    auto t1 = buildStruct!Test(parseSource(s1));
    assert(t1.str == "hello");
    auto t2 = buildStruct!Test(parseSource(s2));
    assert(t2.str == "okda");
}

///
Tag buildTag(T)(auto ref const T st)
{
    auto tag = new Tag;
    fillTag(tag, st);
    return tag;
}

///
void fillTag(T)(Tag parent, auto ref const T st)
    if (is(T == struct))
{
    static void addValue(X)(Tag ct, X val)
    {
        static if (is(X == enum))
            ct.add(Value(val.to!string));
        else static if (isFloatingPoint!X)
        {
            if (val == val) ct.add(Value(val.to!FloatingType));
            else ct.add(Value("nan"));
        }
        //static if (isNumeric!X) // WTF? on windows dmd-nightly (2.080) isNumeric!bool is true
        else static if (isNumeric!X && !is(Unqual!X == bool))
            ct.add(Value(val.to!int));
        else static if (is(X == const(ubyte)[]))
            ct.add(Value(cast(ubyte[])val.dup));
        else
            ct.add(Value(cast(Unqual!X)val));
    }

    foreach (i, ref f; st.tupleof)
    {
        alias FT = Unqual!(typeof(f));
        enum name = __traits(identifier, st.tupleof[i]);

        static if (name != "this") // const(void)* context ptr
        {
            static if (isUserStruct!FT)
                fillTag(new Tag(parent, "", name), f);
            else static if (isSerializableArray!FT)
            {
                static if (isUserStruct!(Unqual!(ElementType!FT)))
                {
                    if (f.length)
                        foreach (v; f)
                            fillTag(new Tag(parent, "", name), v);
                    else
                        new Tag(parent, "", name);
                }
                else
                {
                    auto ct = new Tag(parent, "", name);
                    foreach (v; f)
                        addValue(ct, v);
                }
            }
            else
            {
                auto ct = new Tag(parent, "", name);
                addValue(ct, f);
            }
        }
    }
}

unittest
{
    static struct Test
    {
        string str = "okda";

        static struct Inner
        {
            int abc = 12;
        }

        Inner inner;
    }

    auto t1 = Test("hello");

    auto tt1 = buildTag(t1);

    assert(tt1.getTagValue!string("str") == "hello");
    assert(tt1.getTag("inner").getTagValue!int("abc") == 12);
}

version (unittest)
{
    struct Foo
    {
        bool boolValue;
        int intValue = 12;
        double doubleValue = 0.0;
        string stringValue = "okda";
        ubyte[] ubyteArrValue = [0xa, 0xb];
    }
}

unittest
{
    auto st = buildStruct!Foo(`
    boolValue true
    `.parseSource);

    assert(st.boolValue == true);
    assert(st.intValue == 12);
    assert(st.doubleValue == 0.0);
    assert(st.stringValue == "okda");
    assert(st.ubyteArrValue == [0xa, 0xb]);
}

unittest
{
    auto st = buildStruct!Foo(`
    boolValue2 true
    `.parseSource);

    assert(st.boolValue == false);
    assert(st.intValue == 12);
    assert(st.doubleValue == 0.0);
    assert(st.stringValue == "okda");
    assert(st.ubyteArrValue == [0xa, 0xb]);
}

unittest
{
    import std.base64;
    auto st = buildStruct!Foo((`
    ubyteArrValue [`~Base64.encode(cast(ubyte[])[0xab, 0xbc, 0xcd])~`]
    `).idup.parseSource);

    assert(st.boolValue == false);
    assert(st.intValue == 12);
    assert(st.doubleValue == 0.0);
    assert(st.stringValue == "okda");
    assert(st.ubyteArrValue == [0xab, 0xbc, 0xcd]);
}

unittest
{
    import std.base64;
    auto st = buildStruct!Foo((`
    ubyteArrValue [`~Base64.encode(cast(ubyte[])[0xab, 0xbc, 0xcd])~`]
    ubyteArrValue [`~Base64.encode(cast(ubyte[])[0xcd])~`]
    `).idup.parseSource);

    assert(st.boolValue == false);
    assert(st.intValue == 12);
    assert(st.doubleValue == 0.0);
    assert(st.stringValue == "okda");
    assert(st.ubyteArrValue == [0xcd]);
}

version (unittest)
{
    struct Dt
    {
        Date date;
        DateTimeFrac dtf;
        SysTime systime;
        DateTimeFracUnknownZone dtfuz;
        Duration duration;
    }
}

unittest
{
    auto st = buildStruct!Dt(`
    date 2018/12/06
    `.parseSource);
    assert (st.date == Date(2018, 12, 06));
}

unittest
{
    auto st = buildStruct!Dt(`
    dtf 2018/12/06 15:05:12
    `.parseSource);
    assert (st.dtf != DateTimeFrac(DateTime(2018, 12, 06, 15, 05, 13)));
    assert (st.dtf == DateTimeFrac(DateTime(2018, 12, 06, 15, 05, 12)));
}

unittest
{
    auto st = buildStruct!Dt(`
    duration 2:32:11.123
    `.parseSource);
    assert (st.duration != 2.hours + 32.minutes + 12.seconds + 123.msecs);
    assert (st.duration == 2.hours + 32.minutes + 11.seconds + 123.msecs);
}

unittest
{
    auto st = buildStruct!Dt(`
    duration 2:32:11.123
    `.parseSource);
    assert (st.duration != 2.hours + 32.minutes + 12.seconds + 123.msecs);
    assert (st.duration == 2.hours + 32.minutes + 11.seconds + 123.msecs);
}

unittest
{
    auto st = buildStruct!Dt(`
    duration 5d:2:32:11.123
    `.parseSource);
    assert (st.duration != 5.days + 2.hours + 32.minutes + 12.seconds + 123.msecs);
    assert (st.duration == 5.days + 2.hours + 32.minutes + 11.seconds + 123.msecs);

}

version (unittest)
{
    enum initialFoo = Foo(true, 42, 2.2, "hhh", [0xc, 0xd]);

    struct Bar
    {
        bool[] boolValue = [true, true, false, true];
        int[] intValue = [3, 5, 7, 8];
        double[] doubleValue = [0.0];
        string[] stringValue = ["hello", "world"];
        Duration[] durArr = [5.minutes, 2.seconds];
        Foo[] foo = [initialFoo];
    }
}

unittest
{
    auto st = buildStruct!Bar(`
    `.parseSource);

    assert(st.boolValue == [true, true, false, true]);
    assert(st.intValue == [3,5,7,8]);
    assert(st.doubleValue == [0.0]);
    assert(st.stringValue == ["hello", "world"]);
    assert(st.durArr == [5.minutes, 2.seconds]);
    assert(st.foo == [initialFoo]);
}

unittest
{
    auto st = buildStruct!Bar(`
    boolValue
    doubleValue
    `.parseSource);

    assert(st.boolValue == []);
    assert(st.intValue == [3,5,7,8]);
    assert(st.doubleValue == []);
    assert(st.stringValue == ["hello", "world"]);
    assert(st.durArr == [5.minutes, 2.seconds]);
    assert(st.foo == [initialFoo]);
}

unittest
{
    auto ttag = `boolValue off on
    stringValue "ok" "da" "net"
    durArr 00:00:00.123 00:00:05 00:01:00
    `.parseSource;
    auto st = buildStruct!Bar(ttag);

    assert(st.boolValue == [false, true]);
    assert(st.intValue == [3,5,7,8]);
    assert(st.doubleValue == [0.0]);
    assert(st.stringValue == ["ok", "da", "net"]);
    assert(st.durArr == [123.msecs, 5.seconds, 1.minutes]);
    assert(st.foo == [initialFoo]);
}

unittest
{
    auto st = buildStruct!Bar(`
    foo {
        boolValue true
    }
    foo {
        boolValue false
    }
    `.parseSource);

    assert(st.boolValue == [true, true, false, true]);
    assert(st.intValue == [3,5,7,8]);
    assert(st.doubleValue == [0.0]);
    assert(st.stringValue == ["hello", "world"]);
    assert(st.durArr == [5.minutes, 2.seconds]);
    assert(st.foo == [Foo(true), Foo(false)]);
}

unittest
{
    static struct Baz {
        int[3] crd = [0, 1, 2];
    }

    assert(buildStruct!Baz(`crd`.parseSource).crd == [0, 1, 2]);
    assert(buildStruct!Baz(`crd 5`.parseSource).crd == [5, 1, 2]);
    assert(buildStruct!Baz(`crd 5 7`.parseSource).crd == [5, 7, 2]);
    assert(buildStruct!Baz(`crd 5 7 8`.parseSource).crd == [5, 7, 8]);
    assert(buildStruct!Baz(`crd 5 7 8 10`.parseSource).crd == [5, 7, 8]);
}

unittest
{
    auto tt = Bar(
        [false, true, false, false, true],
        [1, 4, 8, 15, 16, 23, 42],
        [], ["ok", "da"], [1.minutes, 2.seconds, 5.msecs],
        [Foo(true, 42, 0.0, "hello"),
         Foo(false, 13, 1.1, "world", [0x1, 0x2, 0xa, 0xff])
        ]
    );

    assert(tt == buildStruct!Bar(buildTag(tt)));
}

unittest
{
    struct Dt {
        DateTimeFrac[] dt;
    }

    auto tt = Dt([DateTimeFrac(DateTime(2010, 02, 03, 12, 18, 0), 5.msecs),
                  DateTimeFrac(DateTime(2018, 04, 04, 10, 15, 30)),
    ]);

    assert(tt == buildStruct!Dt(`dt 2010/02/03 12:18:00.005 2018/04/04 10:15:30`.parseSource));
    assert(tt == buildStruct!Dt(buildTag(tt)));
}

unittest
{
    enum Type
    {
        one,
        two,
        three,
    }

    struct TFoo
    {
        Type type = Type.two;
    }

    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);
}

unittest
{
    enum Type
    {
        one,
        two,
        three,
    }

    struct TFoo
    {
        Type[] type = [Type.two, Type.three];
    }

    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);
}

unittest
{
    struct TFoo
    {
        short a=10, b=12;
        byte x=122, y=100;
    }

    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);
}

unittest
{
    struct TFoo
    {
        float x;
    }

    assert(TFoo.init.x is float.nan);
    auto v = TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo.x;
    assert(v != v); // nan
}

unittest
{
    struct TFoo { float[] x; }

    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);

    auto tt = TFoo([1, 2, float.nan, 3]);
    auto nt = tt.buildTag.toSDLDocument.parseSource.buildStruct!TFoo;
    assert(nt.x.length == 4);
    assert(nt.x[0] == 1);
    assert(nt.x[1] == 2);
    assert(nt.x[2] != nt.x[2]);
    assert(nt.x[3] == 3);
}

unittest
{
    struct TFoo
    {
        float a;
        double b;
    }

    auto tt = `
    a 10
    b 12`.parseSource.buildStruct!TFoo;

    assert(tt == TFoo(10,12));
}

unittest
{
    struct TFoo { uint[] x = [1,2,3]; }
    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);
}

unittest
{
    struct TFoo { ulong[] x = [1,2,3]; }
    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);
}

version (unittest)
{
    mixin template FieldsAndAccess(T, E)
        if (is(E == enum))
    {
        alias Field = T;
        alias Enum = E;

        import std.traits: EnumMembers;
        import std.conv : to;
        import std.algorithm : map;
        import std.string : join, format;
        import std.array : array;

        private static pure string buildFields()
        {
            return [EnumMembers!E]
                        .map!(a=>format("Field %s;", a.to!string))
                        .array.join("\n");
        }

        mixin(buildFields());

        static bool isField(string f) pure nothrow @nogc
        { return is(typeof(f.to!E)); }

        ref inout(T) opIndex(E v) inout
        {
            final switch(v)
                foreach (e; EnumMembers!E)
                    case e: return mixin(e.to!string);
        }
    }

}

unittest
{
    enum ASubject { foo, bar, baz }
    enum BSubject { vo, cu }

    static struct Limit { float min, max; }

    static struct ALimits { mixin FieldsAndAccess!(Limit, ASubject); }
    static struct BLimits { mixin FieldsAndAccess!(Limit, BSubject); }

    static struct DiffRule
    {
        enum Type
        {
            ignore = "ignore",
            value  = "value",
            strict = "strict",
        }
        Type type;
        float v = 0.0;

        static DiffRule ignore() @property { return DiffRule(Type.ignore); }
        static DiffRule value(float v) { return DiffRule(Type.value, v); }
        static DiffRule strict() @property { return DiffRule(Type.strict); }
    }

    static struct ADiff
    {
        DiffRule a = DiffRule.strict; ///
        DiffRule b = DiffRule.value(0.01); ///
        DiffRule c = DiffRule.value(1); ///
        DiffRule d = DiffRule.value(0.001); ///
        DiffRule e = DiffRule.strict; ///
    }

    static struct BDiff
    {
        DiffRule a = DiffRule.strict; ///
        DiffRule b = DiffRule.value(5); ///
        DiffRule c = DiffRule.value(1); ///
        DiffRule d = DiffRule.strict; ///
        DiffRule e = DiffRule.strict; ///
        DiffRule f = DiffRule.value(1); ///
        DiffRule g = DiffRule.strict; ///
    }

    static struct BDescription
    {
        ulong id;
        ushort mid = 1;
        string name = "строка utf-8";
        short hours = 1;
        size_t sid;
        float direction = 1;
    }

    static struct CommonSettings
    {
    }

    static struct StorageSettings
    {
        string dbname="./db.sqlite";
        uint updTime = 5 * 60;
    }

    static struct MonitorSettings
    {
        string port = "/dev/ttyUSB0";
        int baudrate = 9600;
    }

    static struct FrontendSettings
    {
        uint count = 100;
        uint maxCount = 2000;
    }

    static struct Serial { ushort party, number; }

    static struct ModbusSlaveSettings
    {
        string port = "/dev/ttyUSB1";
        int baudrate = 9600;
        string mode = "8N1";
        int deviceNo = 4;
        Serial serial = Serial(1,1);
    }

    enum PIN_COUNT = 4;

    static struct RelayOutSettings
    {
        uint[PIN_COUNT] pins = [17, 23, 26, 27];
        string cmd_hi = `raspi-gpio set %s op dh`;
        string cmd_lo = `raspi-gpio set %s op dl`;
    }

    static struct AppSettings
    {
        CommonSettings common;
        StorageSettings storage;
        MonitorSettings monitor;
        FrontendSettings frontend;
        ModbusSlaveSettings mbslave;
        RelayOutSettings relayout;
    }

    static struct LBT { mixin FieldsAndAccess!(float, BSubject); }

    static struct LSettings
    {
        static struct Limits
        {
            ALimits al;
            BLimits bl;
        }

        static struct DiffRules
        {
            ADiff ar;
            BDiff br;
        }

        Limits limits;
        DiffRules diff;
        LBT lbt;
    }

    static struct TFoo
    {
        LSettings[] settings;
        BDescription[] description;
        AppSettings apps;
    }

    assert(TFoo.init.buildTag.toSDLDocument.parseSource.buildStruct!TFoo == TFoo.init);
}