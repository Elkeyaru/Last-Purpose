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
        clueSites = {
            {12595,998},{12916,1204},{13206,1244},{12688,1497},{13230,1691},
            {12148,1728},{12556,1914},{13550,2085},{12762,2206},{13567,2344},
            {12266,2610},{12606,2819},{13696,2967},{13638,3069},{13756,3282},
            {12941,3328},{12318,3591},{12338,3679},{12748,3924},{13587,4074},
            {13620,4130}
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

function LastPurpose.getHeistClue(data, heist)
    if not data or not heist or not heist.clueSites or #heist.clueSites == 0 then return nil end
    if not data.clueSiteIndex or not heist.clueSites[data.clueSiteIndex] then
        data.clueSiteIndex = ZombRand(#heist.clueSites) + 1
    end
    local site = heist.clueSites[data.clueSiteIndex]
    return { x=site[1], y=site[2], z=0, arrivalRadius=28, title="PUNTO DE REUNION", destination="Un punto de reunion en Louisville" }
end
