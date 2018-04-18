/++ SDLang struct serialize
 +/
module sdlss;

public import sdlang;

import std.meta;
import std.traits;
import std.range : ElementType;
import std.datetime;

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

///
void fillStruct(T)(ref T st, Tag[] tags...)
{
    import std.array;

    static if (isArray!T)
        alias Elem = Unqual!(ElementType!T);

    static if (is(T == struct) &&
              !is(T == Date) &&
              !is(T == SysTime) &&
              !is(T == DateTime) &&
              !is(T == DateTimeFrac) &&
              !is(T == DateTimeFracUnknownZone) &&
              !is(T == Duration))
    {
        if (tags.length == 0) return;
        auto tag = tags[$-1];
        foreach (i, ref f; st.tupleof)
        {
            enum name = __traits(identifier, st.tupleof[i]);
            if (name in tag.tags)
                fillStruct(f, tag.tags[name].array);
        }
    }
    else static if (isDynamicArray!T &&
                    !isSomeString!T &&
                    !(is(Unqual!T == ubyte[]))
                   )
    {
        st = [];

        if (tags.length == 0) return;

        static if (is(Elem == struct))
            foreach (ct; tags)
            {
                if (ct.tags.length)
                    st ~= buildStruct!Elem(ct);
            }
        else
        {
            if (tags.length > 1) { /+ TODO warning +/ }
            foreach (v; tags[$-1].values)
                st ~= v.get!Elem;
        }
    }
    else static if (isStaticArray!T)
    {
        if (tags.length == 0) return;
        static if (is(Elem == struct))
        {
            foreach (i, ct; tags)
            {
                if (i >= st.length) break;
                fillStruct(ct, st[i]);
            }
        }
        else
        {
            if (tags.length > 1) { /+ TODO warning +/ }
            foreach (i, v; tags[$-1].values)
            {
                if (i >= st.length) break;
                st[i] = v.get!Elem;
            }
        }
    }
    else
    {
        if (tags.length == 0) return;
        if (tags.length > 1) { /+ TODO warning +/ }
        if (tags[$-1].values.length == 0) return;
        st = tags[$-1].values[0].get!T();
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
        static if (isNumeric!X)
            ct.add(Value(cast(Unqual!(Signed!X))val));
        else static if (is(X == const(ubyte)[]))
            ct.add(Value(cast(ubyte[])val.dup));
        else
            ct.add(Value(cast(Unqual!X)val));
    }

    foreach (i, ref f; st.tupleof)
    {
        alias FT = typeof(f);
        enum name = __traits(identifier, st.tupleof[i]);

        static if (is(FT == struct))
            fillTag(new Tag(parent, "", name), f);
        else static if (isArray!FT && !isSomeString!FT && !(is(Unqual!FT == const(ubyte)[])))
        {
            static if (is(ElementType!FT == struct))
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
    pragma(msg, "issue #1");
    /+ See issue #1 
    assert(st.durArr == [123.msecs, 5.seconds, 1.minutes]);
     +/
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
        [], ["ok", "da"], [/+BUG#1+/], [
            Foo(true, 42, 0.0, "hello"),
            Foo(false, 13, 1.1, "world", [0x1, 0x2, 0xa, 0xff])
        ]
    );

    auto rr = buildStruct!Bar(buildTag(tt));

    assert(tt == rr);
}