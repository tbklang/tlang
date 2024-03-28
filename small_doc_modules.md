Programs, modules and management
================================

It is deserving of its own chapter due to the complexities involved in the system - that is _the module management_ system. There are certain aspects to it which are allured to in other chapters such as the _resolution process_, the _code emit process with `DGen`_ and so forth. Due to this I will therefore only mention new information here rather than re-iterate all of that which belongs squarely in the documentation for those components of the compiler.

## Introduction

It is worth first defining what a _module_ is and hwo this relates to the compiler at large. Firstly a _program_ (see `Program`) is made up of one or more _modules_ (see `Module`).

A module can contain code such as global variable definitions, import statements, function definitions to name a few. Every module has a name within the given program and these names must be unique (TODO: check if that is enforced).

---

Below we show the directory structure of an example program that could be compiled:

```bash
source/tlang/testing/modules/
├── a.t
├── b.t
├── niks
│   └── c.t
```

Each of these files within the directory shown above is now shown below so you can see their contents, next to it we provide their module names as well (TODO: Ensure these match on `parse()` enter):

##### Module `a` at file `a.t`

```d
module a;

import niks.c;
import b;

int ident(int i)
{
	return i;
}

int main()
{
	int value = b.doThing();
	return value;
}
```

> Notice here that we import modules in the same directory just with their name. It's basically $module_{path} = module_{name}+".t"$. Directory structure is also taken into account, hence in order to reference the module `c` we must import it as `niks.c` as that will resolve to `niks/c.t` as the file path.

##### Module `b` at file `b.t`

```d
module b;

import a;

int doThing()
{
    int local = 0;

    for(int i = 0; i < 10; i=i+1)
    {
        local = local + a.ident(i);
    }

    return local;
}
```

##### Module `c` at file `niks/c.t`

```d
module c;

import a;

void k()
{
    
}
```

---

You could then go ahead and compile such a program by specifying the entrypoint module:

```bash
# Compile module a
./tlang compile source/tlang/testing/modules/a.t
```

Then running it, our code should return with an exit code of `45` due to what we implemented in the `b` module and how we used it in `a` which had our `main()` method:

```bash
# Run the output executable
./tlang.out

# Print the exit code
echo $?
```

> Note, the module you specify on the command-line will have its directory used as the base search path for the rest of the modules. Therefore specifying `a.t` or `b.t` is fine as they reside in the same directory whereby `niks/` can be found ut this is not true if you compiles `niks/c.t` as that would only see the search directory from `niks/` downwards - upwards searching does **not** occur

## Structure of a program

The *program*, as mentioned prior, is what holds all the associated *modules*. We shall now take a look at some of the internals of this type.

## Structure of a Module

TODO: Not sure if this should be here, but eh, maybe worth it

## Module management

The *module manager* is responsible for maintaining a list of so-called *search paths* and being able to take a query for a given module (by name) and attempt to find it within said *paths*.

### The `ModuleEntry`

The first type we should start off with an analysis of is the `ModuleEntry` type. This is a simple struct which associates a module's **name** with a given **filename** (in the form of an absolute path).

```d
/** 
 * Represents the module-name to
 * file path mapping
 */
public struct ModuleEntry
{
    /** 
     * Absolute path to the module's file
     */
    private string filename;

    /** 
     * The module's name
     */
    private string moduleName;

    /** 
     * Constructs a new module entry
     * from the given name and absolute
     * path to the module file itself
     *
     * Params:
     *   filename = the absolute opath
     * of the module itself
     *   moduleName = the module's name
     */
    this(string filename, string moduleName)
    {
        this.filename = filename;
        this.moduleName = moduleName;
    }
    
    /** 
     * Checks if the module entry
     * is valid which checks that
     * both the file path and name
     * have a length greater than `0`
     * and that the filepath is
     * an absolute path
     *
     * Returns: `true` if valid,
     * `false` otherwise
     */
    public bool isValid()
    {
        return moduleName.length && filename.length && isAbsolute(filename);
    }

    /** 
     * Obtains the oath to
     * the module's file
     *
     * Returns: the path
     */
    public string getPath()
    {
        return this.filename;
    }

    /** 
     * Obtains the module's name
     *
     * Returns: the name
     */
    public string getName()
    {
        return this.moduleName;
    }

    /** 
     * Checks if the current module entry
     * is equal to the other by means of
     * comparison of their file paths
     *
     * Params:
     *   rhs = the module to compare to
     * Returns: `true` if equal, otherwise
     * `false`
     */
    public bool opEquals(ModuleEntry rhs)
    {
        return this.filename == rhs.filename;
    }
}
```

The above definition is all you really need to know about this type, this simple is a tuple of sorts with some helper methods to extract the two tuple values of $(module_{name}, module_{path})$ and doing validation of these values.

### The module manager

The *module manager* defined in the `ModuleManager` type, it contains the following constructor method:

| Constructor      | Description |
|------------------|-------------|
| `this(Compiler)` | Constructs a new `ModuleManager` using the given `Compiler` instance. This will automatically add the search paths from the `"modman:path"` configuration entry to the module manager during construction. |

It then also contains the following methods:

| Method                   | Return type | Description | 
|--------------------------|-------------|-------------|
| `addSearchPath(string)`  | `void`      | Adds the given path to the set of search paths |
| `addSearchPaths(string[])` | `void`    | Adds each of the provided paths to the set of search paths |
| `find(string)`           | `ModuleEntry`| This searches all search paths for a _module file_ with the given _module name_ and then returns the `ModuleEntry` for it if found, else a `ModuleManagerError` is thrown |

#### How searching works

We have now shown you the more frequently used API but there are, however, some more internal methods which are used in order to perform the actual searching.

There is a method declared with the following signature:

```d
private bool find
(
    string[] directories,
    string modName,
    ref ModuleEntry found,
    bool isDirect = true
)
```

This method is at the core of searching, most other methods are either called _from_ it or call to it as simple proxy methods. I will now go into the details of how this method works when searching is performed and the various branches it may take during a search.

##### Parameters

Firstly this method takes in a `string[]` of absolute paths to directories. Normally this will be passed a `this.searchPaths`, meaning that effectively the way this method is used is that it will be performing searches from those paths.

Secondly we have the `modName` parameter. This one is rather self-explanatory - it is the _module's name_ we are searching for.

Next we have the `found` parameter, which takes in a pointer to a `ModuleEntry` struct variable. This is only set when a module with the name of `modName` is actually found.

Lastly, we have the `isDirect` parameter which has a default value of `true`. This controls whether a further search is done if the module being searched for is not found during the shallow search.

##### Return value

The return value is a `bool` and is `true` when a `ModuleEntry` is found, `false` otherwise. This is just so you know whether or not the reference parameter `found` was updated or not; i.e. if a module by the given name was found or not.

---

So let's take an example. We had a module structure as follows:

```bash
source/tlang/testing/modules/
├── a.t
├── b.t
├── niks
│   └── c.t
```

Now if we were searching for the modules named `a` or `b` and gave the `directories` of `["source/tlang/testing/modukes/"]` then we would find those tow modules (ins separate calls of course) immediately within the shallow search performed.

However, if we searched for a module named `niks.c` with the same directories provided we would **not** find a file named `c.t` within the directory of `source/tlang/testing/modules/`. Now, if `isDirect` is set to `true` then what happens is as follows:

TODO: We should do check here for . in `modName` and then enter loop and calculate

1. First we check if the given `modName` contains any periods (`.`s) in its name. We need this as they indicate the directory structure of the new search paths we will need to calculate. If it has none then we return immediately with `false` as the module cannot be found (and there is no reasonable way to find it with a nested search).
2. We then calculate a `newModName` by the incoming `modName`, for example `niks.c`, and just popping off the tail such that we then have `"c"` as the value of `newModName` - we will need this later.

1. First we will iterate over each of the directory names in `directories`. let's call the iterator variable `directory`
    b. We then take the module's name, say `niks.c` and replace the `.`s with `/`s. Now we have `niks/c`.
    c. We then remove the tail end such that we just have `bruh/`. Let's call this `relativeDir`.
    d. Now we construct a new search path by combining the following `directory` + "/" + `relativeDir`. Call this result `newSearchPath`.
2. Each iteration of the above stores their respective `newSearchPath` into an array called `newPaths`. We currently do **NOT** (TODO: Optimize it later) stop when we found a file which exists, so technically all of these `newSearchPath`(s) are constructed to only be checked for validity later. This checking is performed later.
3. Now we do a recursive call to `find(...)` with `newPaths` as the search directories, the module name we search for is then that of `newModName`. Following the example that means we are searching for a module named `c` in the search `directories` calculated, in this case, as `["source/tlang/testing/modules/niks"]`. Importantly, however, we pass `isDirect=false` for this call because we have calculated all possible paths just from the `modName` provided, so we just need to do one nested call to search a modified `modName` (see `newModName`) in the modified search directories (see `newPaths`).

TODFO

| `findAllTFilesShallow(string)` | `string[]` | Searches the directory at the given path and returns the absolute paths of all files ending in `.t` |