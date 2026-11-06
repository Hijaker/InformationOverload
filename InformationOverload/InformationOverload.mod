return {
    run = function()
        fassert(rawget(_G, "new_mod"), "Information Overload requires Darktide Mod Framework.")
        new_mod("information_overload", {
            mod_script = "InformationOverload/scripts/mods/InformationOverload/information_overload",
            mod_data = "InformationOverload/scripts/mods/InformationOverload/information_overload_data",
            mod_localization = "InformationOverload/scripts/mods/InformationOverload/information_overload_localization",
        })
    end,
    packages = {},
}
