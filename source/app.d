import std.stdio;
import std.file, std.path, std.json, std.conv, std.string;
import std.format, std.getopt, std.typecons;
import twitter4d;
import eaw;

struct SettingFile {
  string default_account;
  string[string][string] accounts;
}

SettingFile readSettingFile(string path) {
  if (!exists(path)) {
    throw new Exception("No such a file - %s".format(path));
  }

  SettingFile ret;
  string elem = readText(path);
  auto parsed = parseJSON(elem);

  if ("default_account" in parsed.object) {
    ret.default_account = parsed.object["default_account"].str;
  } else {
    throw new Exception("No such a field - %s".format("default_account"));
  }

  if ("accounts" in parsed.object) {
    foreach (key, value; parsed.object["accounts"].object) {
      foreach (hk, hv; value.object) {
        ret.accounts[key][hk] = hv.str;
      }
    }
  } else {
    throw new Exception("No such a field - %s".format("accounts"));
  }

  return ret;
}

string str_rep(string pat, size_t n) {
  string ret;
  foreach (_; 0 .. n) {
    ret ~= pat;
  }
  return ret;
}

dstring str_adjust_len(dstring str, size_t len) {
  dstring[] splitted = str.split("\n");
  dstring[] buf;

  foreach (elem; splitted) {
    if (len < elem.east_asian_width) {
      size_t split_point;

      for (; elem[0 .. split_point].east_asian_width < len; split_point++) {
      }

      buf ~= elem[0 .. split_point];
      buf ~= elem[split_point .. $];
    } else {
      buf ~= elem;
    }
  }

  return buf.join("\n");
}

struct WinSize {
  int width;
  int height;
}

WinSize getWinSize() {
  import core.sys.posix.sys.ioctl, core.sys.posix.unistd;

  winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != -1) {
    return WinSize(ws.ws_col, ws.ws_row);
  } else {
    throw new Exception("Failed to get winsize");
  }
}

void main(string[] args) {
  string specified_account;
  string count = "20";

  auto helpInformation = getopt(args, "account|a", "specify the account to tweet",
      &specified_account, "count|c", "count of tweets", &count);
  if (helpInformation.helpWanted) {
    defaultGetoptPrinter("Usage:", helpInformation.options);
    return;
  }

  // Please edit the below path where you want
  string dir = expandTilde("~/.myscripts/ctl");
  string setting_file_name = "setting.json";
  SettingFile sf = readSettingFile("%s/%s".format(dir, setting_file_name));

  if (specified_account is null) {
    specified_account = sf.default_account;
  }

  auto t4d = new Twitter4D(sf.accounts[specified_account]);
  auto result = t4d.request("GET", "statuses/home_timeline.json", [
      "count": count
      ]);

  auto parsed = parseJSON(result);

  size_t line_width = getWinSize().width;
  foreach_reverse (elem; parsed.array) {
    writeln(str_rep("-", line_width));
    dstring name = "%s(@%s)".format(elem.object["user"].object["name"].str,
        elem.object["user"].object["screen_name"]).to!dstring;
    dstring created_at = elem.object["created_at"].str.to!dstring;
    string pad = str_rep(" ", line_width - (east_asian_width(name) + east_asian_width(created_at)));
    writefln("%s%s%s", name, pad, created_at);
    writeln(elem.object["text"].str.to!dstring.str_adjust_len(line_width));
  }
}