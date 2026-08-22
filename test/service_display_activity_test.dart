import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowith/core/utils/service_display.dart';

void main() {
  test('serviceActivityLabel prioriza el nombre final de la actividad', () {
    expect(
      serviceActivityLabel({
        'activity_name': 'Acompañarme a una feria de emprendimiento',
        'subcategory_name': 'Otra actividad cotidiana',
        'category_name': 'Actividades sociales',
      }),
      'Acompañarme a una feria de emprendimiento',
    );
    expect(
      serviceActivityLabel({
        'subcategory_name': 'Ir al cine',
        'category_name': 'Actividades sociales',
      }),
      'Ir al cine',
    );
  });

  test('activityIconFromCode usa iconos estables y un fallback', () {
    expect(activityIconFromCode('movie'), Icons.movie_outlined);
    expect(activityIconFromCode('coffee'), Icons.local_cafe_outlined);
    expect(activityIconFromCode('other'), Icons.auto_awesome_outlined);
    expect(activityIconFromCode('unknown'), Icons.category_outlined);
  });
}
