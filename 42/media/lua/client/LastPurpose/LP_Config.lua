LastPurpose = LastPurpose or {}
LastPurpose.VERSION = "0.3.1"
LastPurpose.ACTIVATION_DAYS = 15
LastPurpose.SAVE_KEY = "LastPurpose"
LastPurpose.TRACKER_KEY = Keyboard.KEY_J
LastPurpose.OBJECTIVES = {
 { key="crowbar", label="Palanca" }, { key="screwdriver", label="Destornillador" },
 { key="flashlight", label="Linterna" }, { key="bag", label="Bolsa o mochila" },
 { key="vehicle", label="Vehiculo funcional con combustible" },
}
LastPurpose.TOOL_TYPES = {
 ["Base.Crowbar"]="crowbar", ["Base.CrowbarForged"]="crowbar",
 ["Base.Screwdriver"]="screwdriver", ["Base.Screwdriver_Old"]="screwdriver",
 ["Base.Screwdriver_Improvised"]="screwdriver", ["Base.HandTorch"]="flashlight",
 ["Base.Torch"]="flashlight",
}
