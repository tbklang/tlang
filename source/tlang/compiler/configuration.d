module tlang.compiler.configuration;

import tlang.compiler.core : CompilerException, CompilerError;
import std.string : cmp;

private union ConfigValue
{
    ulong number;
    bool boolean;
    string text;
    string[] textArray;
}

public enum ConfigType
{
    NUMBER,
    BOOLEAN,
    TEXT,
    TEXT_ARRAY
}

public struct ConfigEntry
{
    private string name;
    private ConfigValue value;
    private ConfigType type;

    private this(string entryName, ConfigType entryType)
    {
        this.name = entryName;
        this.type = entryType;
    }

    this(VType)(string entryName, VType valType)
    {
        this(entryName, ConfigType.TEXT);
        value.text = to!(string)(valType);
    }

    this(string entryName, ulong entryValue)
    {
        this(entryName, ConfigType.NUMBER);
        value.number = entryValue;
    }
    
    this(string entryName, bool entryValue)
    {
        this(entryName, ConfigType.BOOLEAN);
        value.boolean = entryValue;
    }

    this(string entryName, string entryValue)
    {
        this(entryName, ConfigType.TEXT);
        value.text = entryValue;
    }

    this(string entryName, string[] entryValue)
    {
        this(entryName, ConfigType.TEXT_ARRAY);
        value.textArray = entryValue;
    }

    public ulong getNumber()
    {
        if(type == ConfigType.NUMBER)
        {
            return value.number;
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_TYPE_ERROR, "Type mismatch for key '"~name~"'");
        }
    }

    public bool getBoolean()
    {
        if(type == ConfigType.BOOLEAN)
        {
            return value.boolean;
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_TYPE_ERROR, "Type mismatch for key '"~name~"'");
        }
    }

    public string getText()
    {
        if(type == ConfigType.TEXT)
        {
            return value.text;
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_TYPE_ERROR, "Type mismatch for key '"~name~"'");
        }
    }

    public string[] getArray()
    {
        if(type == ConfigType.TEXT_ARRAY)
        {
            return value.textArray;
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_TYPE_ERROR, "Type mismatch for key '"~name~"'");
        }
    }

    public string getName()
    {
        return name;
    }

    public ConfigType getType()
    {
        return type;
    }
    
}

public final class CompilerConfiguration
{
    private ConfigEntry[] entries;

    public void addConfig(ConfigEntry entry)
    {
        // If duplicate then update entry
        if(hasConfig(entry.getName()))
        {
            updateConfig(entry);
        }
        // Else, add a new entry
        else
        {
            entries ~= entry;
        }
    }

    private void updateConfig(ConfigEntry newEntry)
    {
        for(ulong i = 0; i < entries.length; i++)
        {
            if(cmp(entries[i].getName(), newEntry.getName()) == 0)
            {
                if(entries[i].getType() == newEntry.getType())
                {
                    entries[i] = newEntry;
                    break;
                }
                else
                {
                    throw new CompilerException(CompilerError.CONFIG_TYPE_ERROR, "Tried updating an entry to a different type");
                }
            }
        }
    }

    public ConfigEntry getConfig(string key)
    {
        ConfigEntry foundEntry;
        if(hasConfig_internal(key, foundEntry))
        {
            return foundEntry;
        }
        else
        {
            throw new CompilerException(CompilerError.CONFIG_KEY_NOT_FOUND);
        }
    }

    private bool hasConfig_internal(string key, ref ConfigEntry foundEntry)
    {
        foreach(ConfigEntry curEntry; entries)
        {
            if(cmp(curEntry.getName(), key) == 0)
            {
                foundEntry = curEntry;
                return true;
            }
        }
        return false;
    }

    public bool hasConfig(string key)
    {
        ConfigEntry _discard;
        return hasConfig_internal(key, _discard);
    }

    /** 
     * Generates the default compiler configuration
     *
     * Returns: a `CompilerConfguration`
     */
    public static CompilerConfiguration defaultConfig()
    {
        /* Generate a fresh new config */
        CompilerConfiguration config = new CompilerConfiguration();

        /* Enable Behaviour-C fixes */
        config.addConfig(ConfigEntry("behavec:preinline_args", true));

        /* Enable pretty code generation for DGen */
        config.addConfig(ConfigEntry("dgen:pretty_code", true));

        /* Enable entry point test generation for DGen */
        config.addConfig(ConfigEntry("dgen:emit_entrypoint_test", true));

        /* Set the mapping to hashing of entity names (TODO: This should be changed before release) */
        config.addConfig(ConfigEntry("emit:mapper", "hashmapper"));

        /**
         * Configure, at compile time, the system type aliases
         */
        version(X86)
        {
            /* Set maximum width to 4 bytes (32-bits) */
            config.addConfig(ConfigEntry("types:max_width", 4));
        }
        else version(X86_64)
        {
            /* Set maximum width to 8 bytes (64-bits) */
            config.addConfig(ConfigEntry("types:max_width", 8));
        }

        return config;
    }
}