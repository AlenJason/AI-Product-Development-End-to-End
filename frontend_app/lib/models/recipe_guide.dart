import 'api/meal_plan.dart';

class CookingStep {
  const CookingStep({
    required this.stepNumber,
    required this.title,
    required this.duration,
    required this.instruction,
    this.tip,
  });

  final int stepNumber;
  final String title;
  final String duration;
  final String instruction;
  final String? tip;
}

class RecipeGuide {
  const RecipeGuide({
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.steps,
    required this.cookingTip,
    required this.nutritionNote,
  });

  final int prepMinutes;
  final int cookMinutes;
  int get totalMinutes => prepMinutes + cookMinutes;
  int get estimatedMinutes => totalMinutes;
  final String difficulty;
  final List<CookingStep> steps;
  final String cookingTip;
  final String nutritionNote;

  static RecipeGuide forMeal(Meal meal) {
    final lowerName = meal.name.toLowerCase();

    // 1. BÁNH XÈO
    if (lowerName.contains('bánh xèo')) {
      return const RecipeGuide(
        prepMinutes: 7,
        cookMinutes: 12,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Pha bột bánh chuẩn tỷ lệ',
            duration: '7 phút',
            instruction:
                '• Tôm tươi bóc vỏ, bỏ chỉ đen, rửa sạch để ráo. Thịt nạc thái lát thật mỏng.\n'
                '• Ướp tôm thịt với 1/3 thìa cà phê hạt nêm và chút tiêu xay trong 5 phút.\n'
                '• Cho 50g bột gạo vào tô, thêm 1 quả trứng gà và 100ml nước lọc. Dùng phới khuấy đều tay cho bột tan hoàn toàn, mịn mượt không vón cục. Thêm hành lá cắt nhỏ vào âu bột.',
            tip: 'Thêm trứng gà vào bột gạo giúp vỏ bánh xèo vàng xốp thơm ngậy và tăng lượng protein nạp vào.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Xào săn nhân tôm thịt',
            duration: '3 phút',
            instruction:
                '• Đặt chảo chống dính lên bếp, cho 1/2 thìa cà phê dầu ăn vào đun nóng trên lửa vừa.\n'
                '• Cho tôm và thịt vào xào nhanh tay khoảng 2 phút đến khi tôm chuyển màu đỏ cam, thịt chín săn lại thì trút ngay ra đĩa riêng.',
            tip: 'Chỉ xào chín tới 80% để tôm thịt không bị khô khi tiếp tục om cùng bánh xèo.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Đổ bánh xèo & Đậy nắp om chín',
            duration: '4 phút',
            instruction:
                '• Vặn lửa lớn làm chảo thật nóng, quết một lớp dầu ăn mỏng đều khắp mặt chảo.\n'
                '• Múc 1 vá bột đổ vào lòng chảo, nhanh tay nghiêng lắc chảo thành vòng tròn để bột tráng một lớp mỏng đều khắp đáy chảo.\n'
                '• Rải đều phần nhân tôm thịt lên một nửa mặt bánh, đậy nắp vung lại 2 phút trên lửa vừa để hơi nóng làm chín mặt trên của bánh.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Chiên giòn rụm & Thưởng thức',
            duration: '3 phút',
            instruction:
                '• Mở nắp vung, rưới vài giọt dầu ăn quanh mép rìa bánh.\n'
                '• Hạ nhỏ lửa chiên thêm 1–2 phút cho đến khi rìa bánh tự róc ra khỏi chảo và đáy bánh vàng ruộm giòn tan.\n'
                '• Dùng xẻng gập đôi bánh lại, gắp ra đĩa thưởng thức nóng cùng rau cải xanh, xà lách và nước mắm tỏi ớt pha loãng.',
            tip: 'Chiên mở vung ở phút cuối lửa nhỏ là bí quyết giúp vỏ bánh giòn lâu mà không ngấm dầu.',
          ),
        ],
        cookingTip:
            'Nên dùng chảo chống dính tốt để tráng bột mỏng đều và chỉ cần dùng 1 thìa cà phê dầu ăn, tiết kiệm hơn 120 kcal so với cách chiên ngập dầu truyền thống.',
        nutritionNote:
            'Món ăn cung cấp đủ 20g đạm từ tôm và trứng gà, 45g tinh bột từ bột gạo và lượng chất béo thực vật lành mạnh đạt chuẩn 370 kcal cho bữa sáng.',
      );
    }

    // 2. BÚN / PHỞ / MIẾN BÒ HOẶC GÀ
    if (lowerName.contains('bún') || lowerName.contains('phở') || lowerName.contains('miến')) {
      final isChicken = lowerName.contains('gà');
      final meatName = isChicken ? 'Thịt gà nạc' : 'Thịt bò nạc';
      final carbName = lowerName.contains('phở') ? 'bánh phở' : (lowerName.contains('miến') ? 'miến dong' : 'bún tươi');

      return RecipeGuide(
        prepMinutes: 5,
        cookMinutes: 12,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Thái thịt đúng thớ',
            duration: '5 phút',
            instruction:
                '• $meatName rửa sạch với nước muối loãng, dùng khăn giấy sạch thấm thật khô ráo.\n'
                '• Đặt dao vuông góc thớ thịt, thái từng lát thật mỏng (dày khoảng 1–2mm) để khi chần thịt đạt độ mềm ngọt tự nhiên, không dai.\n'
                '• Hành lá, rau thơm rửa sạch thái nhỏ; đập dập 1 củ hành tím và phần đầu củ hành trắng.',
            tip: 'Thái ngang thớ là bí quyết quan trọng nhất giúp thịt bò/gà nạc mềm ngọt mà không cần tẩm ướp bột năng.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Nấu nước dùng thanh ngọt tự nhiên',
            duration: '8 phút',
            instruction:
                '• Cho khoảng 500–600ml nước vào nồi cùng hành tím đập dập và 1 lát gừng mỏng, đun sôi bùng trên bếp.\n'
                '• Nêm 1 thìa cà phê nước mắm ngon, 1/2 thìa cà phê hạt nêm và chút tiêu xay vừa miệng.\n'
                '• Hạ lửa vừa đun sôi lăn tăn trong 5–7 phút để vị ngọt của củ hành gừng tiết đều ra nước dùng, hớt bọt để nước thật trong.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Trụng $carbName & Chần thịt vừa chín tới',
            duration: '3 phút',
            instruction:
                '• Nấu nồi nước sôi riêng, thả $carbName vào trụng nhanh trong 20–30 giây rồi vớt ra để ráo nước, xới tơi và cho vào tô sâu lòng.\n'
                '• Vặn lửa lớn cho nồi nước dùng sôi sùng sục, gắp từng phần $meatName nhúng vào nước sôi trong 30–45 giây cho thịt vừa chín tới (chuyển sang màu hồng tái hoặc trắng chín) thì vớt ngay ra đặt lên mặt bát.',
            tip: 'Tuyệt đối không đun thịt quá lâu trong nồi nước dùng vì thịt nạc ít mỡ sẽ bị khô cứng và hao hụt chất ngọt.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Chan nước dùng nóng & Dùng bữa',
            duration: '1 phút',
            instruction:
                '• Rải hành ngò, rau thơm và vài lát ớt tươi lên mặt tô.\n'
                '• Múc nước dùng đang sôi thật nóng chan đều ngập mặt bún và thịt.\n'
                '• Vắt thêm 1 lát chanh tươi, dùng ngay khi tô còn bốc khói nghi ngút cùng đĩa rau sống tươi sạch.',
          ),
        ],
        cookingTip:
            'Nước dùng ninh từ củ quả và hành nướng giúp nước ngọt thanh tự nhiên mà không cần bột ngọt hay đường phèn.',
        nutritionNote:
            'Thịt nạc cung cấp đạm sạch chất lượng cao hỗ trợ nuôi cơ bắp, trong khi $carbName cung cấp năng lượng tinh bột hấp thu vừa phải cho cả buổi sáng.',
      );
    }

    // 3. BÁNH MÌ TRỨNG ỐP LA
    if (lowerName.contains('bánh mì')) {
      return const RecipeGuide(
        prepMinutes: 3,
        cookMinutes: 5,
        difficulty: 'Rất dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế rau dưa & Ổ bánh mì',
            duration: '3 phút',
            instruction:
                '• Dưa leo, rau mùi rửa sạch, ngâm nước muối loãng 5 phút rồi thái lát xéo mỏng.\n'
                '• Dùng dao xẻ dọc một bên ổ bánh mì. Làm nóng bánh mì trong chảo nóng hoặc nồi chiên không dầu 2 phút cho vỏ giòn tan.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Rán trứng ốp la lòng đào',
            duration: '3 phút',
            instruction:
                '• Đun nóng chảo chống dính với 1/2 thìa cà phê dầu ăn trên lửa vừa.\n'
                '• Đập trứng gà vào chảo, rắc chút tiêu xay lên mặt. Giữ nguyên chảo trong 2 phút cho lòng trắng chín vàng se lại và lòng đỏ vừa chín tới dẻo ngậy.',
            tip: 'Đậy nắp chảo 30 giây cuối nếu bạn muốn ăn trứng chín kỹ cả hai mặt.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Kẹp nhân & Thưởng thức',
            duration: '2 phút',
            instruction:
                '• Phết vài giọt nước tương (xì dầu) hoặc chút tương ớt vào ruột bánh mì.\n'
                '• Khéo léo đặt trứng ốp la vào giữa, kẹp thêm dưa leo giòn và rau mùi thơm.\n'
                '• Thưởng thức ngay khi bánh còn nóng giòn rụm.',
          ),
        ],
        cookingTip:
            'Nên dùng nồi chiên không dầu làm giòn bánh mì ở 160°C trong 2 phút để bánh thơm ngon như vừa ra lò.',
        nutritionNote:
            'Một bữa sáng nhanh gọn hoàn hảo với nguồn đạm giàu choline từ trứng gà cùng chất xơ từ dưa leo và rau thơm.',
      );
    }

    // 4. MÓN XÀO (Ức gà xào nấm, Thịt bò xào ớt chuông, Tôm xào...)
    if (lowerName.contains('xào')) {
      final isBeef = lowerName.contains('bò');
      final isChicken = lowerName.contains('gà');
      final isShrimp = lowerName.contains('tôm');
      final meatLabel = isBeef ? 'Thịt bò' : (isChicken ? 'Ức gà' : (isShrimp ? 'Tôm tươi' : 'Thịt nạc'));

      return RecipeGuide(
        prepMinutes: 8,
        cookMinutes: 8,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Ướp gia vị vừa ăn',
            duration: '8 phút',
            instruction:
                '• $meatLabel rửa sạch, thái miếng mỏng vừa ăn (hoặc bóc vỏ nếu là tôm).\n'
                '• Ướp cùng 1/2 thìa cà phê hạt nêm, 1/2 thìa cà phê nước tương, chút tiêu và 1 tép tỏi băm trong 7–10 phút cho ngấm vị.\n'
                '• Rau củ (nấm, ớt chuông hoặc rau cải) rửa sạch, cắt miếng vừa ăn để ráo nước.',
            tip: 'Ướp một chút xíu dầu ăn vào thịt trước khi xào giúp giữ nước ngọt bên trong, thịt không bị khô.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Xào săn chất đạm trên lửa lớn',
            duration: '3 phút',
            instruction:
                '• Đun nóng chảo cùng 1/2 thìa cà phê dầu ăn, phi thơm tỏi băm.\n'
                '• Cho $meatLabel vào xào nhanh tay trên lửa lớn trong 2–3 phút đến khi thịt vừa săn chín tới khoảng 80% thì trút ra đĩa riêng.',
            tip: 'Xào lửa lớn giúp bề mặt thịt săn ngay lập tức, giữ trọn vị ngọt mọng nước bên trong.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Xào rau củ giữ độ giòn ngọt',
            duration: '3 phút',
            instruction:
                '• Tận dụng chảo, cho rau củ vào xào trên lửa lớn.\n'
                '• Châm thêm 1–2 thìa nước lọc để hơi nước giúp rau củ chín đều nhanh chóng mà vẫn giữ màu xanh tươi giòn ngọt.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Hòa quyện & Hoàn thiện món ăn',
            duration: '2 phút',
            instruction:
                '• Trút đĩa $meatLabel trở lại chảo, đảo đều cùng rau củ trong 1 phút trên lửa lớn cho hòa quyện hương vị.\n'
                '• Nêm nếm lại cho vừa khẩu vị, rắc tiêu thơm, hành lá cắt khúc rồi tắt bếp ngay. Bày ra đĩa dùng cùng cơm nóng.',
          ),
        ],
        cookingTip:
            'Xào riêng thịt và rau củ là kỹ thuật chuẩn giúp rau giữ độ giòn ngọt tự nhiên mà thịt không bị ra nước dai bã.',
        nutritionNote:
            'Món xào ít dầu cung cấp đầy đủ protein xây dựng cơ bắp và chất chống oxy hóa tự nhiên từ rau củ tươi.',
      );
    }

    // 5. ĐẬU PHỤ SỐT CÀ CHUA / MÓN SỐT
    if (lowerName.contains('đậu phụ') || lowerName.contains('đậu hũ')) {
      return const RecipeGuide(
        prepMinutes: 5,
        cookMinutes: 12,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế đậu & Cắt thái rau củ',
            duration: '5 phút',
            instruction:
                '• Đậu phụ rửa nhẹ qua nước, thấm khô ráo rồi cắt thành khối vuông vừa ăn (khoảng 2.5–3cm).\n'
                '• Cà chua rửa sạch bổ múi cau hoặc băm nhỏ để dễ nấu sốt. Hành lá rửa sạch cắt nhỏ.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Áp chảo se mặt đậu',
            duration: '4 phút',
            instruction:
                '• Cho 1/2 thìa dầu ăn vào chảo chống dính đun nóng.\n'
                '• Đặt từng miếng đậu vào áp chảo trên lửa vừa khoảng 2 phút mỗi mặt cho vỏ đậu se vàng nhẹ rồi gắp ra đĩa.',
            tip: 'Áp chảo vàng non giúp miếng đậu dai thơm, không bị nát khi om sốt mà dùng rất ít dầu.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Nấu sốt cà chua sánh mịn',
            duration: '4 phút',
            instruction:
                '• Phi thơm đầu hành trong chảo, cho cà chua vào đảo nhuyễn cùng 1/2 thìa nước mắm và 2 thìa nước ấm.\n'
                '• Dùng thìa dầm nhẹ cho cà chua tan nhuyễn thành nước sốt đỏ sánh mịn tự nhiên.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Om đậu ngấm đều vị sốt',
            duration: '4 phút',
            instruction:
                '• Nhẹ nhàng trút đậu phụ vào chảo sốt, múc sốt rưới đều lên mặt đậu.\n'
                '• Hạ nhỏ lửa đun liu riu trong 3–4 phút cho đậu ngấm đều vị chua ngọt thanh dịu của cà chua.\n'
                '• Rắc hành lá thái nhỏ và chút tiêu xay rồi tắt bếp, dùng nóng với cơm trắng.',
          ),
        ],
        cookingTip:
            'Để sốt cà chua lên màu đỏ đẹp tự nhiên, bạn nên chọn cà chua chín mọng và xào kỹ cùng một chút nước mắm.',
        nutritionNote:
            'Đậu phụ là nguồn đạm thực vật thanh lành giàu canxi, kết hợp lycopene từ cà chua giúp bảo vệ tim mạch.',
      );
    }

    // 6. MÓN KHO / RIM
    if (lowerName.contains('kho') || lowerName.contains('rim')) {
      return const RecipeGuide(
        prepMinutes: 10,
        cookMinutes: 18,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Tẩm ướp đậm đà',
            duration: '10 phút',
            instruction:
                '• Nguyên liệu đạm (thịt/cá/tôm) rửa sạch với nước muối loãng, cắt miếng vừa ăn để ráo.\n'
                '• Ướp cùng 1 thìa nước mắm ngon, 1/2 thìa hạt nêm, chút tiêu, hành tím băm và 1/2 thìa nước màu kho thịt trong 10 phút.',
            tip: 'Ướp đủ thời gian giúp gia vị ngấm sâu vào từng thớ thịt, khi kho miếng thịt săn chắc đậm đà.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Đảo săn lên màu cánh gián',
            duration: '4 phút',
            instruction:
                '• Cho nguyên liệu vào nồi cùng chút dầu ăn, bật lửa vừa đảo đều tay trong 3–4 phút cho thịt săn lại và ngấm màu cánh gián đẹp mắt.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Kho nhỏ lửa liu riu',
            duration: '12 phút',
            instruction:
                '• Châm nước ấm vào nồi xăm xắp mặt thịt, đun sôi rồi vặn nhỏ lửa.\n'
                '• Đậy nắp đun liu riu trong 10–12 phút để thịt mềm nhừ và nước kho dần cô đặc sánh lại thơm nức.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Hoàn thành món ăn',
            duration: '2 phút',
            instruction:
                '• Khi nước kho sệt lại óng ả, rắc thêm chút hành lá và tiêu xay thơm nồng rồi tắt bếp. Thưởng thức cùng cơm nóng và rau luộc.',
          ),
        ],
        cookingTip:
            'Dùng nước ấm hoặc nước dừa tươi kho thịt thay cho nước lạnh giúp thịt không bị co cứng và nước kho trong ngọt hơn.',
        nutritionNote:
            'Món kho cung cấp năng lượng dồi dào, ăn kèm cơm trắng và các món canh rau giúp cân đối trọn vẹn chất dinh dưỡng.',
      );
    }

    // 7. MÓN LUỘC / HẤP
    if (lowerName.contains('luộc') || lowerName.contains('hấp')) {
      return const RecipeGuide(
        prepMinutes: 5,
        cookMinutes: 10,
        difficulty: 'Rất dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế sạch sẽ & Khử mùi',
            duration: '5 phút',
            instruction:
                '• Thịt/cá rửa sạch với nước muối và gừng đập dập. Rau củ nhặt sạch lá úa, ngâm nước muối loãng 5 phút rồi để ráo.\n'
                '• Đập dập vài nhánh hành củ hoặc gừng tươi để cho vào nước luộc tạo mùi thơm.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Đun sôi nước luộc',
            duration: '4 phút',
            instruction:
                '• Đun sôi nồi nước vừa đủ ngập nguyên liệu, cho chút muối tinh và gừng đập dập vào nồi để khử mùi và giúp rau giữ màu xanh tươi.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Luộc đúng thời gian chuẩn',
            duration: '6 phút',
            instruction:
                '• Thả nguyên liệu vào nồi nước đang sôi bùng (rau củ luộc 3–5 phút, thịt/cá luộc 8–12 phút tùy độ dày).\n'
                '• Dùng đũa xiên thử, nếu không còn nước hồng chảy ra là thịt đã chín tới mọng nước. Vớt ra để nguội bớt.',
            tip: 'Rau luộc xong có thể ngâm ngay vào âu nước đá lạnh 1 phút để rau giòn sần sật và giữ màu xanh mướt.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Thái lát & Thưởng thức',
            duration: '2 phút',
            instruction:
                '• Thái thịt thành từng lát mỏng vừa ăn, bày ra đĩa cùng rau luộc. Chấm cùng nước mắm tỏi ớt hoặc nước tương gừng.',
          ),
        ],
        cookingTip:
            'Luộc và hấp là phương pháp nấu ăn số 1 cho người tập gym và giảm cân, giúp bảo toàn 100% dinh dưỡng và không sinh chất béo xấu.',
        nutritionNote:
            'Nước luộc rau thịt có thể nêm chút gia vị và vắt thêm lát chanh làm bát nước canh thanh mát giải nhiệt cho bữa ăn.',
      );
    }

    // 8. MÓN CANH / SÚP / CHÁO
    if (lowerName.contains('canh') || lowerName.contains('súp') || lowerName.contains('cháo')) {
      return const RecipeGuide(
        prepMinutes: 6,
        cookMinutes: 10,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế rau củ & Thịt băm/tôm',
            duration: '6 phút',
            instruction:
                '• Rau cải/rau ngót/bí đỏ rửa sạch, cắt khúc hoặc vò dập nhẹ để khi nấu rau mềm ngọt nước.\n'
                '• Thịt băm hoặc tôm ướp nhẹ chút tiêu và 1/3 thìa hạt nêm trong 5 phút.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Xào thơm nguyên liệu đạm',
            duration: '2 phút',
            instruction:
                '• Đun nóng nồi cùng vài giọt dầu ăn, phi thơm đầu hành rồi trút thịt/tôm vào đảo săn trong 1–2 phút cho thơm lừng.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Nấu nước canh ngọt trong',
            duration: '5 phút',
            instruction:
                '• Châm khoảng 400–500ml nước sôi vào nồi, đun sôi bùng lên và dùng thìa hớt sạch bọt nổi trên mặt để nước canh trong vắt.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Nấu rau chín tới & Nêm nếm',
            duration: '3 phút',
            instruction:
                '• Thả rau củ vào nồi nước đang sôi, nấu chín tới trên lửa lớn (rau xanh nấu 2–3 phút, củ bí nấu 5 phút mềm bùi).\n'
                '• Nêm gia vị vừa miệng, rắc hành ngò thái nhỏ rồi tắt bếp ngay để rau giữ màu xanh tươi mọng.',
            tip: 'Không đậy nắp nồi khi nấu canh rau xanh để rau không bị nồng và không bị úa vàng.',
          ),
        ],
        cookingTip:
            'Nấu canh với nước sôi thay vì nước lạnh giúp rau củ giữ nguyên vitamin và vị ngọt tự nhiên không bị hao hụt.',
        nutritionNote:
            'Bát canh nóng cung cấp chất xơ hòa tan dồi dào, hỗ trợ tiêu hóa tốt và cấp nước thanh lọc cho cơ thể.',
      );
    }

    // 9. MÓN ÁP CHẢO (Cá basa, Ức gà áp chảo...)
    if (lowerName.contains('áp chảo')) {
      return const RecipeGuide(
        prepMinutes: 5,
        cookMinutes: 8,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Thấm khô bề mặt',
            duration: '5 phút',
            instruction:
                '• Cá/thịt rửa sạch với nước muối và chút chanh khử tanh.\n'
                '• Dùng khăn giấy chuyên dụng thấm thật khô hai bề mặt miếng thịt/cá để khi áp chảo không bị bắn dầu và tạo lớp vỏ vàng giòn.\n'
                '• Ướp nhẹ với chút tiêu xay, muối tinh và tỏi băm trong 5 phút.',
            tip: 'Thấm khô bề mặt là bước quyết định giúp cá/thịt áp chảo vàng giòn đẹp mắt mà không dính chảo.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Làm nóng chảo & Quết dầu',
            duration: '2 phút',
            instruction:
                '• Đun nóng chảo chống dính trên lửa vừa, cho 1/2 thìa cà phê dầu ăn tráng đều một lớp mỏng khắp mặt chảo.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Áp chảo vàng giòn hai mặt',
            duration: '6 phút',
            instruction:
                '• Nhẹ nhàng đặt miếng thịt/cá vào chảo, giữ nguyên không di chuyển trong 3–4 phút cho mặt dưới vàng giòn thơm nức.\n'
                '• Dùng kẹp lật mặt còn lại, áp chảo thêm 2–3 phút cho chín đều vào tận bên trong rồi gắp ra đĩa.',
            tip: 'Không lật trở miếng thịt/cá liên tục để tránh miếng thịt bị nát và mất độ ẩm bên trong.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Trình bày & Dùng bữa',
            duration: '1 phút',
            instruction:
                '• Cắt miếng vừa ăn, trang trí cùng vài cọng rau mùi và lát chanh tươi. Thưởng thức nóng cùng cơm trắng và canh rau.',
          ),
        ],
        cookingTip:
            'Áp chảo trên lửa vừa giúp lớp vỏ ngoài vàng rụm mà phần thịt bên trong vẫn mềm ngọt, mọng nước tự nhiên.',
        nutritionNote:
            'Món áp chảo giữ được hàm lượng chất béo tốt Omega-3 và protein tinh khiết rất tốt cho quá trình xây dựng cơ bắp.',
      );
    }

    // 10. FALLBACK THÔNG MINH CHO MỌI MÓN ĂN VIỆT KHÁC
    final mainIngredients = meal.ingredients.map((i) => '${i.name} (${i.amount}${i.unit.code})').take(3).join(', ');
    return RecipeGuide(
      prepMinutes: 8,
      cookMinutes: 12,
      difficulty: 'Dễ',
      steps: [
        CookingStep(
          stepNumber: 1,
          title: 'Chuẩn bị & Sơ chế nguyên liệu',
          duration: '8 phút',
          instruction:
              '• Rửa sạch các nguyên liệu chính: $mainIngredients.\n'
              '• Phần thịt/cá rửa sạch thấm ráo nước, cắt thái miếng vừa ăn theo thớ thịt.\n'
              '• Rau củ nhặt rửa sạch, ngâm nước muối loãng 5 phút rồi cắt khúc để ráo.',
        ),
        const CookingStep(
          stepNumber: 2,
          title: 'Tẩm ướp gia vị nền',
          duration: '5 phút',
          instruction:
              '• Ướp phần nguyên liệu đạm với 1/2 thìa cà phê hạt nêm, 1/3 thìa cà phê tiêu xay, chút hành tím hoặc tỏi băm trong 5–7 phút cho ngấm đều gia vị gia đình.',
          tip: 'Ướp vừa phải, không nêm quá mặn để bảo vệ thận và duy trì vóc dáng săn chắc.',
        ),
        CookingStep(
          stepNumber: 3,
          title: 'Chế biến món ăn theo độ chín chuẩn',
          duration: '10 phút',
          instruction:
              '• Đun nóng nồi/chảo trên bếp với mức lửa vừa cùng lượng dầu ăn tối thiểu theo khẩu phần.\n'
              '• Cho nguyên liệu vào nấu chín tới, kiểm soát nhiệt độ để món ăn đạt độ thơm ngon, mềm ngọt tự nhiên mà không làm cháy hay hao hụt dưỡng chất.',
        ),
        CookingStep(
          stepNumber: 4,
          title: 'Hoàn thiện & Thưởng thức khẩu phần',
          duration: '2 phút',
          instruction:
              '• Bày món ${meal.name} ra đĩa/bát sạch đẹp.\n'
              '• Dùng bữa khi món còn nóng ấm theo đúng khẩu phần ${meal.portion} để đảm bảo nạp chuẩn lượng calo ${meal.calories} kcal.',
        ),
      ],
      cookingTip:
          'Luôn ưu tiên nguyên liệu tươi sạch trong ngày và hạn chế chiên rán ngập dầu để món ăn giữ được tối đa dưỡng chất tự nhiên.',
      nutritionNote:
          'Bữa ăn được tính toán cân bằng tỷ lệ ${meal.proteinG}g đạm, ${meal.carbsG}g tinh bột và ${meal.fatG}g chất béo giúp duy trì vóc dáng khỏe mạnh.',
    );
  }
}
