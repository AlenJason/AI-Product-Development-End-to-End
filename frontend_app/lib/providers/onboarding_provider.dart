import 'package:flutter/material.dart';

class OnboardingProvider extends ChangeNotifier {
  // Basic Info
  int age = 22;
  String gender = 'Nam';
  num heightCm = 168;
  num weightKg = 62;

  // Activity
  String activityLevel = 'Vận động vừa';

  // Goal
  String goal = 'Giảm mỡ';

  // Restrictions
  String allergies = '';
  String injuries = '';
  String healthConditions = '';

  void updateBasicInfo({required int newAge, required String newGender, required num newHeight, required num newWeight}) {
    age = newAge;
    gender = newGender;
    heightCm = newHeight;
    weightKg = newWeight;
    notifyListeners();
  }

  void updateActivity(String level) {
    activityLevel = level;
    notifyListeners();
  }

  void updateGoal(String newGoal) {
    goal = newGoal;
    notifyListeners();
  }

  void updateRestrictions({required String newAllergies, required String newInjuries, required String conditions}) {
    allergies = newAllergies;
    injuries = newInjuries;
    healthConditions = conditions;
    notifyListeners();
  }
}





