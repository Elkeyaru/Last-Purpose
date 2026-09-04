LastPurpose = LastPurpose or {}
LastPurpose.VERSION = "0.7.0"
LastPurpose.DEBUG_FAST_ACTIVATION = false
LastPurpose.ACTIVATION_MINUTES = 20
LastPurpose.ACTIVATION_DAYS = LastPurpose.DEBUG_FAST_ACTIVATION and (LastPurpose.ACTIVATION_MINUTES / (24 * 60)) or 15
LastPurpose.SAVE_KEY = "LastPurpose"
LastPurpose.TRACKER_KEY = Keyboard.KEY_J
LastPurpose.OBJECTIVES = {
 { key="crowbar", label="Palanca" }, { key="screwdriver", label="Destornillador" },
 { key="flashlight", label="Linterna" }, { key="bag", label="Bolsa o mochila" },
 { key="vehicle", label="Vehículo funcional con combustible" },
 { key="safehouse", label="Mesa colocada en el refugio" },
}
LastPurpose.TOOL_TYPES = {
 ["Base.Crowbar"]="crowbar", ["Base.CrowbarForged"]="crowbar",
 ["Base.Screwdriver"]="screwdriver", ["Base.Screwdriver_Old"]="screwdriver",
 ["Base.Screwdriver_Improvised"]="screwdriver", ["Base.HandTorch"]="flashlight",
 ["Base.Torch"]="flashlight",
}
