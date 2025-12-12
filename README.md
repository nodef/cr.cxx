# cr.h

A single file header-only live reload solution for C, written in C++:

- simple public API, 3 functions to use only (and another to export);
- works and tested on Linux, MacOSX and Windows;
- automatic crash protection;
- automatic static state transfer;
- based on dynamic reloadable binary (.so/.dylib/.dll);
- support multiple plugins;
- MIT licensed;

NOTE: The only file that matters in this repository is `cr.h`.

This file contains the documentation in markdown, the license, the implementation and the public api.
All other files in this repository are supporting files and can be safely ignored.

### Installation

Run:
```bash
$ npm i cr.cxx
```

And then include `cr.h` as follows:
```cxx
// main.cxx
#include "node_modules/cr.cxx/cr.h"

int main() { /* ... */ }
```

And then compile with `clang++` or `g++` as usual.

```bash
$ clang++ main.cxx  # or, use g++
$ g++     main.cxx
```

You may also use a simpler approach:

```cxx
// main.cxx
#include <cr.h>

int main() { /* ... */ }
```

If you add the path `node_modules/cr.cxx` to your compiler's include paths.

```bash
$ clang++ -I./node_modules/cr.cxx main.cxx  # or, use g++
$ g++     -I./node_modules/cr.cxx main.cxx
```


### Example

A (thin) host application executable will make use of `cr` to manage
live-reloading of the real application in the form of dynamic loadable binary, a host would be something like:

```c
#define CR_HOST // required in the host only and before including cr.h
#include "cr.h"

int main(int argc, char *argv[]) {
    // the host application should initalize a plugin with a context, a plugin
    cr_plugin ctx;

    // the full path to the live-reloadable application
    cr_plugin_open(ctx, "c:/path/to/build/game.dll");

    // call the update function at any frequency matters to you, this will give
    // the real application a chance to run
    while (!cr_plugin_update(ctx)) {
        // do anything you need to do on host side (ie. windowing and input stuff?)
    }

    // at the end do not forget to cleanup the plugin context
    cr_plugin_close(ctx);
    return 0;
}
```

While the guest (real application), would be like:

```c
CR_EXPORT int cr_main(struct cr_plugin *ctx, enum cr_op operation) {
    assert(ctx);
    switch (operation) {
        case CR_LOAD:   return on_load(...); // loading back from a reload
        case CR_UNLOAD: return on_unload(...); // preparing to a new reload
        case CR_CLOSE: ...; // the plugin will close and not reload anymore
    }
    // CR_STEP
    return on_update(...);
}
```

### Changelog

#### 2025-03-30

- Removed FIPS and moved to pure CMake.
- As a result, cr.h has been moved into the cr directory.
- Using cr as a cmake dependency (`target_link_libraries(<my_target> PRIVATE cr)`) will expose the cr.h header file to the target.

#### 2020-04-19

- Added a failure `CR_INITIAL_FAILURE`. If the initial plugin crashes, the host must determine the next path, and we will not reload
the broken plugin.

#### 2020-01-09

- Deprecated `cr_plugin_load` in favor to `cr_plugin_open` for consistency with `cr_plugin_close`. See issue #49.
- Minor documentation improvements.

#### 2018-11-17

- Support to OSX finished, thanks to MESH Consultants Inc.
- Added a new possible failure `CR_BAD_IMAGE` in case the binary file is stil not ready even if its timestamp changed. This could happen if generating the file (compiler or copying) was slow.
- Windows: Fix issue with too long paths causing the PDB patch process to fail, causing the reload process to fail.
- **Possible breaking change:** Fix rollback flow. Before, during a rollback (for any reason) two versions were decremented one-shot so that the in following load, the version would bump again getting us effectively on the previous version, but in some cases not related to crashes this wasn't completely valid (see `CR_BAD_IMAGE`). Now the version is decremented one time in the crash handler and then another time during the rollback and then be bumped again. A rollback due an incomplete image will not incorrectly rollback two versions, it will continue at the same version retrying the load until the image is valid (copy or compiler finished writing to it). This may impact current uses of `cr` if the `version` info is used during `CR_UNLOAD` as it will now be a different value.

### Samples

Two simple samples can be found in the `samples` directory.

The first is one is a simple console application that demonstrate some basic static
states working between instances and basic crash handling tests. Print to output
is used to show what is happening.

The second one demonstrates how to live-reload an opengl application using
 [Dear ImGui](https://github.com/ocornut/imgui). Some state lives in the host
 side while most of the code is in the guest side.

 ![imgui sample](https://i.imgur.com/Nq6s0GP.gif)

#### Samples and Tests

To build, use the given CMake preset:

```bash
$ cmake --preset Default .
$ cmake --build build
```

To run the tests, you can use the vscode Launch Tests option (Windows only, currently), or:

```bash
$ cd build/tests
$ ctest build
```

To use the basic sample, you can use the vscode Launch basic sample option (Windows only, currently), or:

```bash
$ cd build/samples/basic
$ ./basic_host # or basic_host_b

# Edit basic_guest.c, or just:
$ touch basic_guest.c

# rebuild
$ cmake --build ../../
```

For the imgui sample, after building:
```bash
$ cd build/samples/imgui
$ ./imgui_host

# Edit imgui_guest.cpp, or just:
$ touch imgui_guest.cpp

# rebuild
$ cmake --build ../../
```

### Documentation

#### `int (*cr_main)(struct cr_plugin *ctx, enum cr_op operation)`

This is the function pointer to the dynamic loadable binary entry point function.

Arguments

- `ctx` pointer to a context that will be passed from `host` to the `guest` containing valuable information about the current loaded version, failure reason and user data. For more info see `cr_plugin`.
- `operation` which operation is being executed, see `cr_op`.

Return

- A negative value indicating an error, forcing a rollback to happen and failure
 being set to `CR_USER`. 0 or a positive value that will be passed to the
  `host` process.

#### `bool cr_plugin_open(cr_plugin &ctx, const char *fullpath)`

Loads and initialize the plugin.

Arguments

- `ctx` a context that will manage the plugin internal data and user data.
- `fullpath` full path with filename to the loadable binary for the plugin or
 `NULL`.

Return

- `true` in case of success, `false` otherwise.

#### `void cr_set_temporary_path(cr_plugin& ctx, const std::string &path)`

Sets temporary path to which temporary copies of plugin will be placed. Should be called
immediately after `cr_plugin_open()`. If `temporary` path is not set, temporary copies of
the file will be copied to the same directory where the original file is located.

Arguments

- `ctx` a context that will manage the plugin internal data and user data.
- `path` a full path to an existing directory which will be used for storing temporary plugin copies.

#### `int cr_plugin_update(cr_plugin &ctx, bool reloadCheck = true)`

This function will call the plugin `cr_main` function. It should be called as
 frequently as the core logic/application needs.

Arguments

- `ctx` the current plugin context data.
- `reloadCheck` optional: do a disk check (stat()) to see if the dynamic library needs a reload.

Return

- -1 if a failure happened during an update;
- -2 if a failure happened during a load or unload;
- anything else is returned directly from the plugin `cr_main`.

#### `void cr_plugin_close(cr_plugin &ctx)`

Cleanup internal states once the plugin is not required anymore.

Arguments

- `ctx` the current plugin context data.

#### `cr_op`

Enum indicating the kind of step that is being executed by the `host`:

- `CR_LOAD` A load caused by reload is being executed, can be used to restore any
 saved internal state.
- `CR_STEP` An application update, this is the normal and most frequent operation;
- `CR_UNLOAD` An unload for reloading the plugin will be executed, giving the
 application one chance to store any required data;
- `CR_CLOSE` Used when closing the plugin, This works like `CR_UNLOAD` but no `CR_LOAD`
 should be expected afterwards;

#### `cr_plugin`

The plugin instance context struct.

- `p` opaque pointer for internal cr data;
- `userdata` may be used by the user to pass information between reloads;
- `version` incremetal number for each succeded reload, starting at 1 for the
 first load. **The version will change during a crash handling process**;
- `failure` used by the crash protection system, will hold the last failure error
 code that caused a rollback. See `cr_failure` for more info on possible values;

#### `cr_failure`

If a crash in the loadable binary happens, the crash handler will indicate the
 reason of the crash with one of these:

- `CR_NONE` No error;
- `CR_SEGFAULT` Segmentation fault. `SIGSEGV` on Linux/OSX or
 `EXCEPTION_ACCESS_VIOLATION` on Windows;
- `CR_ILLEGAL` In case of illegal instruction. `SIGILL` on Linux/OSX or
 `EXCEPTION_ILLEGAL_INSTRUCTION` on Windows;
- `CR_ABORT` Abort, `SIGBRT` on Linux/OSX, not used on Windows;
- `CR_MISALIGN` Bus error, `SIGBUS` on Linux/OSX or `EXCEPTION_DATATYPE_MISALIGNMENT`
 on Windows;
- `CR_BOUNDS` Is `EXCEPTION_ARRAY_BOUNDS_EXCEEDED`, Windows only;
- `CR_STACKOVERFLOW` Is `EXCEPTION_STACK_OVERFLOW`, Windows only;
- `CR_STATE_INVALIDATED` Static `CR_STATE` management safety failure;
- `CR_BAD_IMAGE` The plugin is not a valid image (i.e. the compiler may still
writing it);
- `CR_OTHER` Other signal, Linux only;
- `CR_USER` User error (for negative values returned from `cr_main`);

#### `CR_HOST` define

This define should be used before including the `cr.h` in the `host`, if `CR_HOST`
 is not defined, `cr.h` will work as a public API header file to be used in the
  `guest` implementation.

Optionally `CR_HOST` may also be defined to one of the following values as a way
 to configure the `safety` operation mode for automatic static state management
  (`CR_STATE`):

- `CR_SAFEST` Will validate address and size of the state data sections during
 reloads, if anything changes the load will rollback;
- `CR_SAFE` Will validate only the size of the state section, this mean that the
 address of the statics may change (and it is best to avoid holding any pointer
  to static stuff);
- `CR_UNSAFE` Will validate nothing but that the size of section fits, may not
 be necessarelly exact (growing is acceptable but shrinking isn't), this is the
 default behavior;
- `CR_DISABLE` Completely disable automatic static state management;

#### `CR_STATE` macro

Used to tag a global or local static variable to be saved and restored during a reload.

Usage

`static bool CR_STATE bInitialized = false;`

#### Overridable macros

You can define these macros before including cr.h in host (CR_HOST) to customize cr.h
 memory allocations and other behaviours:

- `CR_MAIN_FUNC`: changes 'cr_main' symbol to user-defined function name. default: #define CR_MAIN_FUNC "cr_main"
- `CR_ASSERT`: override assert. default: #define CA_ASSERT(e) assert(e)
- `CR_REALLOC`: override libc's realloc. default: #define CR_REALLOC(ptr, size) ::realloc(ptr, size)
- `CR_MALLOC`: override libc's malloc. default: #define CR_MALLOC(size) ::malloc(size)
- `CR_FREE`: override libc's free. default: #define CR_FREE(ptr) ::free(ptr)
- `CR_DEBUG`: outputs debug messages in CR_ERROR, CR_LOG and CR_TRACE
- `CR_ERROR`: logs debug messages to stderr. default (CR_DEBUG only): #define CR_ERROR(...) fprintf(stderr, __VA_ARGS__)
- `CR_LOG`: logs debug messages. default (CR_DEBUG only): #define CR_LOG(...) fprintf(stdout, __VA_ARGS__)
- `CR_TRACE`: prints function calls. default (CR_DEBUG only): #define CR_TRACE(...) fprintf(stdout, "CR_TRACE: %s\n", __FUNCTION__)

### FAQ / Troubleshooting

#### Q: Why?

A: Read about why I made this [here](https://fungos.github.io/blog/2017/11/20/cr.h-a-simple-c-hot-reload-header-only-library/).

#### Q: My application asserts/crash when freeing heap data allocated inside the dll, what is happening?

A: Make sure both your application host and your dll are using the dynamic
 run-time (/MD or /MDd) as any data allocated in the heap must be freed with
  the same allocator instance, by sharing the run-time between guest and
   host you will guarantee the same allocator is being used.

#### Q: Can we load multiple plugins at the same time?

A: Yes. This should work without issues on Windows. On Linux and OSX there may be
issues with crash handling

#### Q: You said this wouldn't lock my PDB, but it still locks! Why?

If you had to load the dll before `cr` for any reason, Visual Studio may still hold a lock to the PDB. You may be having [this issue](https://github.com/fungos/cr/issues/12) and the solution is [here](https://stackoverflow.com/questions/38427425/how-to-force-visual-studio-2015-to-unlock-pdb-file-after-freelibrary-call).

#### Q: Hot-reload is not working at all, what I'm doing wrong?

First, be sure that your build system is not interfering by somewhat still linking to your shared library. There are so many things that can go wrong and you need to be sure only `cr` will deal with your shared library. On linux, for more info on how to find what is happening, check [this issue](https://github.com/fungos/cr/issues/9).

#### Q: How much can I change things in the plugin without risking breaking everything?

`cr` is `C` reloader and dealing with C it assume simple things will mostly work.

The problem is how the linker will decide do rearrange things accordingly the amount of changes you do in the code. For incremental and localized changes I never had any issues, in general I hardly had any issues at all by writing normal C code. Now, when things start to become more complex and bordering C++, it becomes riskier. If you need do complex things, I suggest checking [RCCPP](https://github.com/RuntimeCompiledCPlusPlus/RuntimeCompiledCPlusPlus) and reading [this PDF](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter15_Runtime_Compiled_C++_for_Rapid_AI_Development.pdf) and my original blog post about `cr` [here](https://fungos.github.io/blog/2017/11/20/cr.h-a-simple-c-hot-reload-header-only-library/).

With all these information you'll be able to decide which is better to your use case.

### `cr` Sponsors

![MESH](https://static1.squarespace.com/static/5a5f5f08aeb625edacf9327b/t/5a7b78aa8165f513404129a3/1534346581876/?format=150w)

#### [MESH Consultants Inc.](http://meshconsultants.ca/)
**For sponsoring the port of `cr` to the MacOSX.**

### Contributors

[Danny Grein](https://github.com/fungos)

[Rokas Kupstys](https://github.com/rokups)

[Noah Rinehart](https://github.com/noahrinehart)

[Niklas Lundberg](https://github.com/datgame)

[Sepehr Taghdisian](https://github.com/septag)

[Robert Gabriel Jakabosky](https://github.com/neopallium)

[@pixelherodev](https://github.com/pixelherodev)

[Alexander](https://github.com/clibequilibrium)

[Vikram Saran](https://github.com/vikhik)

### Contributing

We welcome *ALL* contributions, there is no minor things to contribute with, even one letter typo fixes are welcome.

The only things we require is to test thoroughly, maintain code style and keeping documentation up-to-date.

Also, accepting and agreeing to release any contribution under the same license.

----

### License

The MIT License (MIT)

Copyright (c) 2017 Danny Angelo Carminati Grein

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

----

<br>
<br>


[![ORG](https://img.shields.io/badge/org-nodef-green?logo=Org)](https://nodef.github.io)
![](https://ga-beacon.deno.dev/G-RC63DPBH3P:SH3Eq-NoQ9mwgYeHWxu7cw/github.com/nodef/cr.cxx)
