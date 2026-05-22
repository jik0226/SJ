// OfflineNoticeBanner — shown at the top of social screens when the server
// is unreachable, so users understand *before* filling a form that friend /
// group actions won't work yet. Pairs with disabling the relevant buttons.

import SwiftUI

struct OfflineNoticeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(DT.Color.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("지금은 오프라인이에요")
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text("친구 추가·그룹 채팅은 서버 연결 후 사용할 수 있어요. 타이머·플래너 등 혼자 쓰는 기능은 평소처럼 동작합니다.")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(DT.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.warning.opacity(0.12))
        )
    }
}
