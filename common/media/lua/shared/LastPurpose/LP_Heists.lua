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
        clue = {
            x = 12180,
            y = 1888,
            z = 0,
            arrivalRadius = 28,
            title = "PUNTO DE REUNION",
            destination = "Un callejon al oeste de Louisville"
        },
        getaway = {
            x = 12582,
            y = 1722,
            radius = 28
        },
        marker = "X",
        dialogue = {
            "<bzzt> Soy yo. Escucha con atención...",
            "Los documentos siguen escondidos en el punto de reunión.",
            "El callejón está al oeste de Louisville. Nadie debería encontrarlos.",
            "Con esa nota sabremos dónde guardaron el botín antes de evacuar.",
            "Voy a seguir llamando hasta que respondas.",
            "¿Me copiaste? <fzzt>"
        },
        finalLine = "Me copiaste?"
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
