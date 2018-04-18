import std.stdio;
import std.getopt;
import std.file;

import sdlss;

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

int main(string[] args)
{
    string sets_file = "settings.sdl";
    bool gen_default;
    getopt(args,
        "settings-file", &sets_file,
        "gen-default-settings", &gen_default
    );

    if (gen_default)
    {
        stderr.writefln("generate default settings to '%s'", sets_file);
        writeStruct(Settings.init, sets_file);
        return 0;
    }

    if (!sets_file.exists)
    {
        stderr.writefln("no settings file found '%s'", sets_file);
        stderr.writefln("use:\n%s --gen-default-settings", args[0]);
        return 1;
    }

    auto sets = readStruct!Settings(sets_file);

    writeln(sets);

    return 0;
}