import 'api/meal_plan.dart';

class CookingStep {
  const CookingStep({
    required this.stepNumber,
    required this.title,
    required this.instruction,
  });

  final int stepNumber;
  final String title;
  final String instruction;
}

class RecipeGuide {
  const RecipeGuide({
    required this.estimatedMinutes,
    required this.difficulty,
    required this.steps,
    required this.cookingTip,
  });

  final int estimatedMinutes;
  final String difficulty;
  final List<CookingStep> steps;
  final String cookingTip;

  static RecipeGuide forMeal(Meal meal) {
    final lowerName = meal.name.toLowerCase();

    // 1. Các món đặc trưng quen thuộc
    if (lowerName.contains('bánh xèo')) {
      return const RecipeGuide(
        estimatedMinutes: 20,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Pha bột',
            instruction:
                'Tôm rửa sạch bóc vỏ, thịt thái lát mỏng. Hòa bột gạo cùng nước và trứng gà, khuấy đều cho hỗn hợp sánh mịn không vón cục.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Xào nhân bánh',
            instruction:
                'Làm nóng chảo với chút dầu ăn, cho tôm và thịt vào xào nhanh tay trên lửa vừa khoảng 2 phút cho săn chín tới rồi gắp ra.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Đổ bánh xèo',
            instruction:
                'Đun chảo thật nóng, múc 1 vá bột láng đều quanh chảo thật mỏng. Rải tôm thịt lên một nửa mặt bánh, đậy nắp khoảng 2–3 phút.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Chiên giòn & Thưởng thức',
            instruction:
                'Mở nắp, chiên thêm 1–2 phút cho rìa bánh vàng giòn rụm. Gập đôi bánh lại, gắp ra đĩa dùng nóng kèm rau sống và nước mắm chua ngọt.',
          ),
        ],
        cookingTip:
            'Nên dùng chảo chống dính tốt và chỉ dùng một lượng dầu ăn vừa phải để vỏ bánh giòn mà vẫn giữ đúng mức calo mục tiêu.',
      );
    }

    if (lowerName.contains('bún') || lowerName.contains('phở') || lowerName.contains('miến')) {
      return RecipeGuide(
        estimatedMinutes: 15,
        difficulty: 'Dễ',
        steps: [
          const CookingStep(
            stepNumber: 1,
            title: 'Sơ chế nguyên liệu',
            instruction:
                'Trụng sơ bún/phở qua nước sôi rồi vớt ra để ráo. Thịt rửa sạch thái lát mỏng; rau thơm, hành lá rửa sạch và cắt nhỏ.',
          ),
          const CookingStep(
            stepNumber: 2,
            title: 'Nấu nước dùng',
            instruction:
                'Đun sôi nồi nước dùng, nêm chút hạt nêm, nước mắm vừa miệng (có thể thêm hành nướng hoặc gừng đập dập cho dậy mùi thơm).',
          ),
          const CookingStep(
            stepNumber: 3,
            title: 'Làm chín thịt',
            instruction:
                'Thả thịt vào nồi nước dùng đang sôi chần nhanh cho thịt chín mềm ngọt tự nhiên, không để quá lâu tránh dai.',
          ),
          const CookingStep(
            stepNumber: 4,
            title: 'Trình bày & Thưởng thức',
            instruction:
                'Xếp bún/phở vào tô, xếp thịt lên trên, chan nước dùng thật nóng, rắc hành ngò và thưởng thức cùng chút chanh ớt.',
          ),
        ],
        cookingTip:
            'Hạn chế húp hết phần nước béo nếu bạn đang trong giai đoạn giảm mỡ để kiểm soát lượng chất béo nạp vào.',
      );
    }

    if (lowerName.contains('bánh mì')) {
      return const RecipeGuide(
        estimatedMinutes: 10,
        difficulty: 'Rất dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Chuẩn bị',
            instruction:
                'Rửa sạch dưa leo, rau mùi và thái lát mỏng. Dùng dao xẻ dọc một bên ổ bánh mì.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Chế biến nhân',
            instruction:
                'Đun nóng chảo với chút dầu ăn, đập trứng gà vào ốp la lòng đào hoặc rán chín vàng đều hai mặt theo sở thích.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Kẹp bánh mì',
            instruction:
                'Làm nóng bánh mì cho giòn, phết chút xì dầu hoặc tương ớt, cho trứng ốp la, dưa leo và rau mùi vào giữa.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Hoàn thành',
            instruction:
                'Thưởng thức ngay khi bánh còn nóng giòn cho một bữa sáng tiện lợi, giàu protein.',
          ),
        ],
        cookingTip:
            'Nướng sơ bánh mì bằng nồi chiên không dầu hoặc chảo nóng khoảng 2 phút để bánh giòn rụm thơm ngon hơn.',
      );
    }

    if (lowerName.contains('đậu phụ') || lowerName.contains('đậu hũ')) {
      return const RecipeGuide(
        estimatedMinutes: 15,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế đậu & sốt',
            instruction:
                'Đậu phụ cắt miếng vuông vừa ăn. Cà chua rửa sạch bổ múi cau hoặc băm nhỏ. Hành lá cắt nhỏ.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Áp chảo đậu',
            instruction:
                'Cho chút dầu vào chảo, rán sơ các mặt đậu phụ cho vàng nhẹ và săn chắc rồi vớt ra để ráo dầu.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Nấu sốt cà chua',
            instruction:
                'Phi thơm đầu hành, cho cà chua vào đảo nhuyễn cùng chút gia vị và xíu nước để tạo thành sốt sánh mịn.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Om đậu ngấm vị',
            instruction:
                'Trút đậu vào chảo sốt, hạ nhỏ lửa đun liu riu 3–5 phút cho đậu ngấm đều vị sốt, rắc hành lá rồi tắt bếp.',
          ),
        ],
        cookingTip:
            'Áp chảo nhẹ thay vì chiên ngập dầu giúp món ăn thanh đạm, ít cholesterol và tốt cho tim mạch.',
      );
    }

    // 2. Nhận diện theo phương pháp chế biến chính
    if (lowerName.contains('xào')) {
      final proteinIng = meal.ingredients.where((i) => i.category.code == 'protein');
      final proteinName = proteinIng.isNotEmpty ? proteinIng.first.name : 'thịt/hải sản';
      return RecipeGuide(
        estimatedMinutes: 15,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Ướp gia vị',
            instruction:
                '$proteinName rửa sạch thái miếng vừa ăn, ướp với chút hạt nêm, tiêu và tỏi băm trong 10 phút. Rau củ rửa sạch để ráo.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Xào săn chất đạm',
            instruction:
                'Làm nóng chảo với chút dầu ăn, phi thơm tỏi rồi cho $proteinName vào đảo nhanh tay trên lửa lớn đến khi vừa chín tới thì trút ra đĩa.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Xào rau củ',
            instruction:
                'Tận dụng chảo, cho rau củ vào xào trên lửa lớn, thêm chút xíu nước để rau chín đều mà vẫn giữ được độ giòn ngọt tự nhiên.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Trộn đều & Hoàn thành',
            instruction:
                'Trút đĩa $proteinName vào chảo đảo chung với rau củ thêm 1 phút, nêm nếm lại vừa miệng, rắc tiêu thơm và tắt bếp.',
          ),
        ],
        cookingTip:
            'Xào trên lửa lớn trong thời gian ngắn giúp rau giữ nguyên vitamin và thịt mềm mọng nước, không bị khô dai.',
      );
    }

    if (lowerName.contains('kho') || lowerName.contains('rim') || lowerName.contains('sốt')) {
      return const RecipeGuide(
        estimatedMinutes: 25,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Ướp đậm đà',
            instruction:
                'Thịt/cá rửa sạch, thái miếng vừa ăn. Ướp với hành tím băm, nước mắm, hạt tiêu và một chút nước màu trong 15 phút.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Đảo săn nguyên liệu',
            instruction:
                'Cho vào nồi đảo đều trên lửa vừa khoảng 3–5 phút cho thịt/cá săn lại và ngấm đều gia vị lên màu đẹp.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Kho nhỏ lửa',
            instruction:
                'Thêm một lượng nước ấm vừa xăm xắp mặt, đun sôi rồi hạ nhỏ lửa đun liu riu khoảng 15–20 phút cho nước kho sánh lại.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Hoàn thành',
            instruction:
                'Khi nước kho sệt lại thơm lừng, rắc thêm chút hành lá và tiêu xay, dùng nóng kèm cơm trắng và rau luộc.',
          ),
        ],
        cookingTip:
            'Kho bằng nước dừa tươi hoặc nước ấm sẽ giúp thịt cá mềm thơm và ngọt đậm đà hơn.',
      );
    }

    if (lowerName.contains('luộc') || lowerName.contains('hấp')) {
      return const RecipeGuide(
        estimatedMinutes: 15,
        difficulty: 'Rất dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế sạch sẽ',
            instruction:
                'Rửa sạch nguyên liệu với nước muối loãng. Có thể đập dập vài nhánh gừng hoặc hành củ để luộc/hấp thơm hơn.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Đun sôi nước',
            instruction:
                'Đun sôi nồi nước vừa đủ ngập nguyên liệu, cho gừng và chút muối vào để khử mùi tanh và giữ màu xanh cho rau.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Luộc / Hấp chín tới',
            instruction:
                'Cho nguyên liệu vào nấu chín tới (rau 3–5 phút, thịt/cá 10–15 phút). Vớt ra để ráo, có thể ngâm nước đá nếu muốn rau giòn.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Trình bày & Dùng bữa',
            instruction:
                'Cắt miếng vừa ăn, bày ra đĩa thưởng thức cùng nước mắm ớt hoặc nước tương tỏi gừng.',
          ),
        ],
        cookingTip:
            'Luộc và hấp là phương pháp nấu ăn lý tưởng nhất trong thực đơn thể hình giúp giữ trọn vẹn chất dinh dưỡng và không tăng calo.',
      );
    }

    if (lowerName.contains('canh') || lowerName.contains('súp') || lowerName.contains('cháo')) {
      return const RecipeGuide(
        estimatedMinutes: 15,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế nguyên liệu',
            instruction:
                'Rau củ rửa sạch cắt khúc hoặc thái lát vừa ăn. Thịt băm/tôm ướp nhẹ chút tiêu và hạt nêm.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Xào thơm thịt / tôm',
            instruction:
                'Phi thơm chút đầu hành trong nồi, cho thịt/tôm vào đảo săn trong 1 phút để dậy mùi thơm.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Nấu nước canh',
            instruction:
                'Châm lượng nước sôi vừa khẩu phần ăn vào nồi, đun sôi rồi hớt bọt để nước canh trong ngọt.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Nấu rau & Nêm nếm',
            instruction:
                'Thả rau củ vào nấu chín tới, nêm gia vị vừa ăn, rắc hành ngò rồi tắt bếp ngay để rau giữ màu xanh tươi.',
          ),
        ],
        cookingTip:
            'Tắt bếp ngay khi rau vừa chín tới để giữ lại tối đa hàm lượng vitamin và khoáng chất tự nhiên.',
      );
    }

    if (lowerName.contains('áp chảo') || lowerName.contains('rán') || lowerName.contains('chiên')) {
      return const RecipeGuide(
        estimatedMinutes: 15,
        difficulty: 'Dễ',
        steps: [
          CookingStep(
            stepNumber: 1,
            title: 'Sơ chế & Tẩm ướp',
            instruction:
                'Rửa sạch miếng thịt/cá, dùng khăn giấy thấm thật khô bề mặt để khi áp chảo không bị bắn dầu. Ướp chút muối tiêu và tỏi băm.',
          ),
          CookingStep(
            stepNumber: 2,
            title: 'Làm nóng chảo',
            instruction:
                'Đun nóng chảo chống dính, quết một lớp dầu ăn mỏng đều khắp mặt chảo trên lửa vừa.',
          ),
          CookingStep(
            stepNumber: 3,
            title: 'Áp chảo chín vàng',
            instruction:
                'Đặt thịt/cá vào chảo, giữ nguyên 3–4 phút cho mặt dưới vàng giòn rồi lật mặt còn lại áp chảo chín đều.',
          ),
          CookingStep(
            stepNumber: 4,
            title: 'Hoàn thành',
            instruction:
                'Gắp ra đĩa có lót giấy thấm dầu, cắt miếng vừa ăn và dùng nóng kèm cơm hoặc rau củ.',
          ),
        ],
        cookingTip:
            'Thấm thật khô thịt/cá trước khi áp chảo giúp bề mặt vàng ruộm đẹp mắt mà vẫn mọng nước bên trong.',
      );
    }

    // 3. Fallback thông minh chung cho mọi món ăn
    final ingredientNames = meal.ingredients.map((i) => i.name).take(3).join(', ');
    return RecipeGuide(
      estimatedMinutes: 20,
      difficulty: 'Dễ',
      steps: [
        CookingStep(
          stepNumber: 1,
          title: 'Chuẩn bị nguyên liệu',
          instruction:
              'Rửa sạch các nguyên liệu ($ingredientNames). Cắt thái theo kích cỡ vừa ăn và để ráo nước.',
        ),
        const CookingStep(
          stepNumber: 2,
          title: 'Tẩm ướp gia vị',
          instruction:
              'Ướp thịt/nguyên liệu chính cùng một chút hạt nêm, tiêu và gia vị gia đình vừa miệng trong 10 phút.',
        ),
        const CookingStep(
          stepNumber: 3,
          title: 'Chế biến món ăn',
          instruction:
              'Làm chín các nguyên liệu trên bếp với mức lửa vừa, kiểm soát lượng dầu ăn và nhiệt độ để món ăn chín đều thơm ngon.',
        ),
        CookingStep(
          stepNumber: 4,
          title: 'Hoàn thiện & Dùng bữa',
          instruction:
              'Bày món ${meal.name} ra đĩa/bát, dùng nóng theo đúng khẩu phần ${meal.portion} để đảm bảo mức calo chuẩn.',
        ),
      ],
      cookingTip:
          'Luôn ưu tiên nguyên liệu tươi sạch và kiểm soát gia vị nêm nếm vừa phải để đạt hiệu quả sức khỏe tốt nhất.',
    );
  }
}
