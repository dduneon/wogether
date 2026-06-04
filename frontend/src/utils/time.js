const KST = { timeZone: 'Asia/Seoul' }

function parse(iso) {
  return new Date(iso.endsWith('Z') ? iso : iso + 'Z')
}

/** 전체 날짜+시간: 2025년 6월 5일 오전 01:13 */
export function kstFull(iso) {
  if (!iso) return ''
  return parse(iso).toLocaleString('ko-KR', {
    ...KST,
    year: 'numeric', month: 'long', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

/** 짧은 날짜+시간: 6. 5. 오전 01:13 */
export function kstShort(iso) {
  if (!iso) return ''
  return parse(iso).toLocaleString('ko-KR', {
    ...KST,
    month: 'numeric', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

/** 상대 시간: 방금 전 / N분 전 / N시간 전 / 어제 / N일 전 / 날짜 */
export function kstRelative(iso) {
  if (!iso) return ''
  const diffMs = Date.now() - parse(iso).getTime()
  const diffMin = Math.floor(diffMs / 60000)
  const diffHour = Math.floor(diffMs / 3600000)
  const diffDay = Math.floor(diffMs / 86400000)

  if (diffMin < 1) return '방금 전'
  if (diffMin < 60) return `${diffMin}분 전`
  if (diffHour < 24) return `${diffHour}시간 전`
  if (diffDay === 1) return '어제'
  if (diffDay < 7) return `${diffDay}일 전`
  return kstShort(iso)
}
