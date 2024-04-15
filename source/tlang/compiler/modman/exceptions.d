module tlang.compiler.modman.exceptions;

import tlang.misc.exceptions;
import tlang.compiler.modman.modman : ModuleManager;

public final class ModuleManagerError : TError
{
    this(ModuleManager modMan, string msg)
    {
        super("Module manager '"~modMan.toString()~"' had error: "~msg);
    }
}