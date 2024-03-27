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

TODO: Add


It then also contains the following methods:

TODO: Add