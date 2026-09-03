LastPurpose = LastPurpose or {}

LastPurpose.HEISTS = {
    louisville_knox_bank = {
        id = "louisville_knox_bank",
        title = "La boveda abandonada",
        mission = "Adelantarse a la competencia",
        destination = "Knox Bank, Louisville",
        x = 12564,
        y = 1698,
        arrivalRadius = 35,
        marker = "X",
        dialogue = {
            "<bzzt> ...Confirmaste el lugar?...",
            "Si. El Knox Bank de Louisville sigue cerrado desde la evacuacion.",
            "Dicen que dejaron dinero, joyas y las piezas de la boveda privada.",
            "Entraremos por la parte trasera. Nos vemos alli cuando oscurezca.",
            "No llegues tarde. Esta es nuestra ultima oportunidad. <fzzt>"
        },
        finalLine = "Esta es nuestra ultima oportunidad"
    }
}

LastPurpose.HEIST_ORDER = { "louisville_knox_bank" }

function LastPurpose.getHeist(id)
    return LastPurpose.HEISTS[tostring(id or "")]
end

function LastPurpose.chooseHeistId()
    if #LastPurpose.HEIST_ORDER == 0 then return nil end
    return LastPurpose.HEIST_ORDER[ZombRand(#LastPurpose.HEIST_ORDER) + 1]
end
