# Brief viết cốt truyện — Project X

Lập ngày 09-11-2026. Thông tin lấy từ GDD (bản trích trong `Downloads\_gdd_extract`) và dữ liệu game trong repo tại thời điểm này.

**Cách dùng**

1. Tạo một Project trong Chat, đính kèm file này và các tài liệu ở mục 8.
2. Làm theo thứ tự ở mục 9.
3. File kết quả cuối, viết đúng mẫu ở mục 7, đưa cho một phiên Claude Code để nhập vào game (mục 10).

**Nhãn trạng thái dùng trong file**

- **[ĐÃ CHỐT]**: GDD hoặc designer đã quyết. Giữ nguyên khi viết; muốn đổi thì designer quyết lại.
- **[CHƯA CHỐT]**: designer cần quyết. Chat được đề xuất phương án nhưng phải ghi rõ là đề xuất, không trình bày như đã quyết.
- **[GAME HIỆN TẠI]**: cách game đang chạy. Đổi được nếu truyện cần, nhưng phải nêu ra ở bước nhập.

---

## 1. Tiền đề [ĐÃ CHỐT]

- **Ý tưởng một câu:** game chiến thuật kiểu Fire Emblem. Người chơi chỉ huy một đội nhỏ gồm những người từng là kẻ thù trong chiến tranh, giải các trận như giải đố. Mục tiêu không phải tiêu diệt kẻ địch mà là gây sức ép để các phe tàn quân chấp nhận hòa bình, không để mất ai, và tốt nhất là không giết ai.
- **Bối cảnh:** sau 15 năm chiến tranh giữa Đế quốc Vật lý (người thường, súng, liên lạc tầm xa) và Vương quốc Pháp thuật (người dùng mana, thú nhân), hiệp ước hòa bình được ký. Đội của người chơi đi thuyết phục các nhóm tàn quân không chấp nhận hòa bình.
- **Tuyến truyện MVP:** "Ceasefire Line". Tầm nhìn nhiều tuyến truyện (`cross-storyline-campaign-system.md`) đang tạm dừng, chỉ để tham khảo.
- **Giọng điệu:** truyện hòa giải hậu chiến, cựu thù bị buộc thành đồng minh bất đắc dĩ trong thời đình chiến.
- **Hai trụ cột ảnh hưởng thẳng đến truyện:**
  - *Đội nhỏ, bond sâu:* khi phải chọn giữa thêm nhân vật và đào sâu một mối quan hệ, chọn đào sâu.
  - *Bạo lực có giới hạn:* phe được thuyết phục hay chỉ bị đánh bại quyết định câu chuyện kết thúc theo hướng nào.
- **Độ dài:** 1 map hướng dẫn và 8–12 map chiến dịch chính.

## 2. Luật game mà truyện phải khớp

- [GAME HIỆN TẠI] Vòng một chương: cảnh mở đầu → chuẩn bị → trận → tổng kết → cảnh hậu trận → lưu tự động → sảnh (bond, cửa hàng) → chương sau.
- [ĐÃ CHỐT] Thua trận là Game Over, người chơi chơi lại chương. Không có cảnh thoại khi thua, nên truyện không rẽ nhánh theo trận thua.
- [ĐÃ CHỐT] Không có chết vĩnh viễn: nhân vật ngã trong trận vẫn sống (ở Hard/Nightmare thì phải nghỉ map kế). Truyện không được dựa vào việc nhân vật chết trong trận. Các cảnh "bond bị cắt do tử trận" trong GDD vì vậy không bao giờ xảy ra.
- [ĐÃ CHỐT] Thuyết phục phe tàn quân:
  - Mỗi phe có một ngưỡng số quân bị giết, bí mật và cộng dồn qua các chương.
  - Mỗi phe có một điều kiện thuyết phục, thuộc một trong hai loại: tha đủ một tỉ lệ quân của phe (`units_spared_pct`), hoặc giữ sống một nhân vật chỉ định của phe (`named_unit_alive`).
  - Thắng trận và đạt điều kiện trước khi chạm ngưỡng thì phe **được thuyết phục**.
  - Giết chạm ngưỡng thì phe **không thể thuyết phục**. Nếu lúc hết chương còn phe như vậy, **bad ending** chạy ngay và người chơi chơi lại chương.
  - Trạng thái phe giữ qua các chương: chưa đụng độ / đang đụng độ / đã thuyết phục / không thể thuyết phục. Một phe có thể xuất hiện ở nhiều map.
  - Trong trận người chơi chỉ thấy màu áp lực (xanh → vàng → đỏ), không bao giờ thấy con số.
- [GAME HIỆN TẠI] True ending mở khi mọi chương được đánh dấu "tính cho true ending" đều hoàn thành và mọi phe tàn quân của các chương đó đều được thuyết phục. Game đã tính điều kiện này, nhưng chưa có cảnh true ending.
- [ĐÃ CHỐT] Bond: hai nhân vật tích điểm Support khi đứng cạnh nhau trong trận. Đủ điểm và tới mốc chương thì cảnh hạng kế tiếp mở trong sảnh; người chơi xem (hoặc bỏ qua) cảnh để lên hạng C → B → A. Cảnh viết theo **ngưỡng cảm xúc** của mối quan hệ, không theo kiểu "sau map N thì tự lên hạng".
- [ĐÃ CHỐT] Hạng S: chỉ dành cho các cặp nằm trong danh sách cho phép. Mỗi nhân vật chỉ khóa S với một người, vĩnh viễn. S gồm một **cảnh cam kết** và một **biến thể kết thúc** riêng. [GAME HIỆN TẠI] Game chưa có biến thể kết thúc theo cặp S.
- [GAME HIỆN TẠI] Một câu thoại có thể đặt "cờ cốt truyện" (game ghi nhớ một sự kiện hoặc lựa chọn, có lưu vào save), nhưng hiện chưa có gì đọc cờ để rẽ nhánh. Nếu truyện cần rẽ nhánh, bước nhập phải làm thêm phần đó.
- [GDD có, game chưa làm] Một bond có thể kết thúc theo cốt truyện tại một mốc chương (trừ cặp đã khóa S). Chỉ dùng nếu truyện cần.
- Người chơi bỏ qua được mọi cảnh, nên thông tin cần để chơi (như mục tiêu trận) không được chỉ nằm trong thoại. Màn chuẩn bị đã hiện mục tiêu trận.

## 3. Nhân vật

### 3.1 Mười hai nhân vật trong đội [ĐÃ CHỐT: tên gọi theo class, phe gốc, nhân vật chính]

| Phe gốc | Nhân vật | Mã trong game | Ghi chú |
|---|---|---|---|
| Đế quốc Vật lý | Swordsman (Kiếm sĩ) | `unit_swordsman` | **nhân vật chính**; ngã là thua trận |
| Đế quốc Vật lý | Knight (Kỵ sĩ) | `unit_knight` | nữ, ứng viên S của nhân vật chính |
| Đế quốc Vật lý | Lumberjack | `unit_lumberjack` | |
| Đế quốc Vật lý | Lancer | `unit_lancer` | |
| Đế quốc Vật lý | Gunner | `unit_gunner` | nữ, ứng viên S |
| Đế quốc Vật lý | Wyvern Knight | `unit_wyvern_knight` | nữ, ứng viên S |
| Vương quốc Pháp thuật | Beastwoman | `unit_beastwoman` | nữ, ứng viên S |
| Vương quốc Pháp thuật | Magician | `unit_magician` | nữ, ứng viên S |
| Vương quốc Pháp thuật | Bard | `unit_bard` | |
| Vương quốc Pháp thuật | Healer | `unit_healer` | nữ, ứng viên S |
| Vương quốc Pháp thuật | Magic Swordsman | `unit_magic_swordsman` | giới tính chưa xác định |
| Vương quốc Pháp thuật | Assassin | `unit_assassin` | |

Tài liệu nhân vật hiện có (`project-x-12-characters.docx`, `characters (1).docx`) chỉ mô tả lối đánh và chỉ số. **[CHƯA CHỐT]** tên riêng, giới tính còn thiếu, tính cách, quá khứ, vai trò của từng người trong chiến tranh.

### 3.2 Thứ tự gia nhập

- [ĐÃ CHỐT] Map hướng dẫn: Swordsman và Knight, chỉ phe Đế quốc. Đội "cựu thù" chưa hình thành ở đây.
- [ĐÃ CHỐT] Map 1: thêm Healer và Magician (phe Vương quốc), đội có 4 người chia 2/2. Đội liên quân hình thành từ map này.
- [CHƯA CHỐT] Thứ tự và map gia nhập của 8 người còn lại: Lumberjack, Lancer, Gunner, Wyvern Knight (Đế quốc); Beastwoman, Bard, Magic Swordsman, Assassin (Vương quốc). GDD dặn rõ không được tự đặt thứ tự rồi trình bày như đã quyết.
- [ĐÃ CHỐT] Việc gia nhập là nội dung cốt truyện chắc chắn xảy ra, người chơi không bỏ lỡ được.

### 3.3 Phe tàn quân [CHƯA CHỐT]

- Dữ liệu hiện chỉ có 2 phe mẫu, "Ch01 Rebel Remnant" và "Đội gác sông". Cả hai sẽ được thay.
- Mỗi phe cần có:
  - tên;
  - **động cơ**: vì sao họ từ chối hòa bình;
  - **điều kiện thuyết phục**: mô tả cho truyện, kèm loại (tha bao nhiêu % quân, hoặc phải giữ sống ai);
  - các map phe xuất hiện;
  - thủ lĩnh hoặc nhân vật chủ chốt (bắt buộc nếu điều kiện là giữ sống người đó).
- Ngưỡng số quân bị giết là con số cân bằng, designer chốt riêng, không cần có trong truyện.

### 3.4 Cặp bond

- [ĐÃ CHỐT] Nhân vật chính có tuyến **S romance** với 6 nhân vật nữ: Knight, Gunner, Wyvern Knight, Beastwoman, Magician, Healer. Magic Swordsman chỉ được thêm nếu sau này xác nhận là nữ.
- [CHƯA CHỐT] Các cặp không có nhân vật chính, và cặp nào trong đó được lên S. Nếu một cặp S không phải romance thì ghi rõ loại quan hệ, và designer duyệt trước khi viết.
- [GAME HIỆN TẠI] Điểm Support cần để mở cảnh: C 2, B 5, A 9. Mỗi cảnh có thể đặt "chương sớm nhất được mở".
- Dữ liệu hiện có thêm cặp mẫu Lancer–Gunner (không có S). Đây chỉ là placeholder.

## 4. Các cảnh cần viết

| Cảnh | Khi nào chạy | Số lượng | Mã đề xuất |
|---|---|---|---|
| Mở đầu chương | trước màn chuẩn bị | 1 mỗi chương | `dlg_<chương>_intro` |
| Phản hồi trong trận | thái độ của phe chuyển sang vàng / sang đỏ | 2 mỗi phe, mỗi cảnh 1–2 câu | `dlg_<phe>_feedback_neutral`, `dlg_<phe>_feedback_lost` |
| Hậu trận: phe được thuyết phục | thắng và đạt điều kiện | 1 mỗi phe | `dlg_aftermath_<phe>_persuaded` |
| Hậu trận: phe chưa ngã ngũ ("áp lực tiếp diễn") | thắng nhưng phe vẫn đang đụng độ | 1 cho mỗi lần đụng độ của phe (lần 1, 2, 3…); hết số cảnh đã viết thì lặp lại cảnh cuối | `dlg_aftermath_<phe>_engaged_1`, `_2`, … |
| Hậu trận: thắng thường | map không có phe tàn quân | dùng cảnh "sau trận" của chương, hoặc 1 cảnh chung | `dlg_aftermath_victory` |
| Sau trận của chương | ngay sau cảnh hậu trận của phe | 1 mỗi chương (không bắt buộc) | `dlg_<chương>_post` |
| Bad ending | có phe "không thể thuyết phục" lúc hết chương | 1 mỗi phe, cộng 1 cảnh chung dự phòng | `dlg_bad_ending_<phe>` |
| Gia nhập | khi một nhân vật vào đội | 10 (2 ở map 1, 8 người còn lại) | lồng vào cảnh mở đầu / sau trận (game chưa có ô riêng) |
| Bond C / B / A | người chơi chọn xem trong sảnh | 3 mỗi cặp | `dlg_bond_<a>_<b>_c`, `_b`, `_a` |
| Bond S (cam kết) | sau khi người chơi xác nhận khóa S | 1 mỗi cặp được S | `dlg_bond_<a>_<b>_s` |
| Kết thúc | cuối chiến dịch | true ending; [CHƯA CHỐT] kết thúc thường; biến thể theo cặp S | `dlg_ending_true`, `dlg_ending_normal`, `dlg_ending_s_<a>_<b>` |

- Thứ tự sau một trận thắng: tổng kết → cảnh hậu trận của từng phe (nếu có) → cảnh sau trận của chương → lưu → sảnh. Vì vậy cảnh sau trận không nên lặp lại nội dung cảnh của phe.
- Tiền tố của mã cảnh quyết định nhãn nhỏ phía trên tiêu đề màn thoại: `dlg_bond_` → CẢNH BOND; `dlg_aftermath` → HẬU TRẬN; `dlg_bad_ending` → KẾT THÚC; còn lại → CỐT TRUYỆN. Giữ đúng các tiền tố này. Nhãn cho các cảnh kết thúc khác sẽ được thêm ở bước nhập.

## 5. Định dạng lời thoại [GAME HIỆN TẠI]

- Mỗi cảnh gồm mã cảnh, tên cảnh (hiện thành tiêu đề lớn) và danh sách câu.
- Mỗi câu gồm người nói (để trống nghĩa là người dẫn truyện) và lời thoại. Có thể kèm ảnh chân dung hoặc cờ cốt truyện.
- Mỗi câu tối đa khoảng **150 ký tự**, tức 2 dòng của khung thoại. Câu dài hơn sẽ bị nút Bỏ qua che mất, nên tách thành hai câu.
- Cảnh từ 8 câu trở xuống hiện chấm tiến trình; cảnh dài hơn hiện "n / N". Cảnh phản hồi trong trận nên thật ngắn.
- Hai ngôn ngữ, Việt và Anh. [CHƯA CHỐT] cách lưu trong game. Nên viết tiếng Việt trước, tiếng Anh dịch sau hoặc viết song song. Tên nhân vật, tên phe, tên chương cũng cần cả hai ngôn ngữ.

## 6. Quyết định cần chốt trước hoặc trong khi viết

| # | Quyết định | Ghi chú | Trả lời |
|---|---|---|---|
| 1 | Số map chính (8–12) và tên từng chương | chưa tính map hướng dẫn | |
| 2 | Tên riêng, giới tính còn thiếu, tính cách, quá khứ của 12 nhân vật | tài liệu hiện chỉ có lối đánh | |
| 3 | Thứ tự và map gia nhập của 8 nhân vật còn lại | phần mở đầu đã chốt (mục 3.2) | |
| 4 | Danh sách phe tàn quân: tên, động cơ, điều kiện thuyết phục, các map xuất hiện, thủ lĩnh | ngưỡng giết chốt riêng | |
| 5 | Những chương tính cho true ending | | |
| 6 | Các cặp bond ngoài nhân vật chính, cặp nào được S, loại quan hệ | 6 cặp S của nhân vật chính đã chốt | |
| 7 | Chương sớm nhất mở từng hạng của từng cặp | | |
| 8 | Có kết thúc thường (ngoài true ending và bad ending) không; biến thể kết thúc theo cặp S viết thế nào | game chưa có | |
| 9 | Có rẽ nhánh theo lựa chọn / cờ cốt truyện không | game chưa hỗ trợ | |
| 10 | Có bond kết thúc theo cốt truyện không | GDD có, game chưa làm | |
| 11 | Cách viết hai ngôn ngữ | | |
| 12 | Gắn truyện vào map nào | 6 map demo chỉ để tham khảo; chờ map chính thức hay tạm gắn vào map demo | |

## 7. Mẫu đầu ra (để nhập thẳng vào game)

Mỗi câu thoại nằm trên một dòng bắt đầu bằng `- `, các trường cách nhau bằng ` | `. Chưa có bản tiếng Anh thì để `en:` trống. Người nói dùng tên hiển thị đã chốt; người dẫn truyện ghi `(narrator)`.

**Phần A: dàn ý chiến dịch**

```
## CAMPAIGN

### CHAPTER chapter_01
title_vi: ...
title_en: ...
map: (chưa có)
factions: faction_x
recruits: unit_healer, unit_magician
true_ending: yes

### FACTION faction_x
name_vi: ...
name_en: ...
motivation_vi: ...
persuasion: named_unit_alive unit_x_leader      # hoặc: units_spared_pct 0.6
appears_in: chapter_01, chapter_03

### BOND bond_swordsman_knight
units: unit_swordsman + unit_knight
s: yes (romance)
earliest: C chapter_00, B chapter_02, A chapter_04, S chapter_06
```

**Phần B: từng cảnh**

```
## SCENE dlg_chapter_01_intro
kind: story          # story | feedback | aftermath | bond | bad_ending | ending
title_vi: ...
title_en: ...
- Swordsman | vi: ... | en: ...
- (narrator) | vi: ... | en: ...
- Healer | vi: ... | en: ... | flag: met_healer | portrait: healer_smile
```

## 8. Tài liệu đính kèm vào Project trong Chat

Trong `C:\Users\kame1\Downloads\_gdd_extract\nguon\Nguồn\`:

- `game-concept.md`: ý tưởng, trụ cột, giọng điệu.
- `narrative-bond-scene-system.md`: khi nào cảnh chạy, cảnh hậu trận, gia nhập.
- `faction-system.md` và `persuasion-system.md`: phe tàn quân, điều kiện thuyết phục.
- `unit-roster-system.md`: 12 nhân vật, thứ tự gia nhập.
- `bond-adjacency-system.md` và `GHI_CHU_BOND\bond-support-revision-2026-10-07.md`: bond và hạng S.
- Tham khảo thêm: `FULL_VISION_TAM_DUNG\cross-storyline-campaign-system.md` (tầm nhìn nhiều tuyến truyện, đang tạm dừng).

Trong `C:\Users\kame1\Downloads\`:

- `project-x-12-characters.docx` (hoặc `characters (1).docx`): lối đánh từng nhân vật.
- `Project-X-Master-Design (1).xlsx`.

Và chính file brief này.

## 9. Thứ tự làm việc gợi ý trong Chat

1. Đọc brief và tài liệu, tóm tắt lại những gì đã chốt và những gì còn mở. Không tự quyết thay designer.
2. Cùng designer chốt bảng ở mục 6. Chat đề xuất phương án, ghi rõ đó là đề xuất.
3. Viết dàn ý chiến dịch theo phần A của mục 7.
4. Viết cảnh theo từng chương: mở đầu, phản hồi trong trận, hậu trận, sau trận, bad ending.
5. Viết cảnh bond theo ngưỡng cảm xúc của từng cặp.
6. Viết các cảnh kết thúc: true ending và các biến thể.
7. Dịch sang tiếng Anh nếu chưa viết song song.
8. Xuất một file cuối theo đúng mẫu ở mục 7.

## 10. Bước nhập vào game (phiên Claude Code)

Mở phiên trong `C:\Users\kame1\OneDrive\Tài liệu\egine\project-x`, đưa đường dẫn file kết quả kèm yêu cầu:

> Đưa cốt truyện trong file này vào game theo AGENTS.md: ghi quyết định vào §7b trước; thay thoại placeholder; nối vào chương, phe và cặp bond; làm mốc cốt truyện và thứ tự gia nhập; hỗ trợ hai ngôn ngữ cho thoại và tên; làm thêm những phần game chưa có mà truyện cần (cảnh kết thúc, biến thể theo cặp S, rẽ nhánh theo cờ nếu có); chạy validate và test; chỉ commit trên máy, không push.
