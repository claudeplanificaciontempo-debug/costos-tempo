# crear-usuario

Función del servidor que crea usuarios de Costos TEMPO.

La llave de administrador de Supabase (service role) **no puede vivir en
`index.html`**: cualquiera que abra el enlace de la app la vería y podría hacer
lo que quisiera con la base. Por eso la creación de usuarios se hace aquí, en el
servidor, donde esa llave está guardada.

Qué hace, en orden:

1. Lee la sesión de quien llama (la cabecera `Authorization`).
2. Comprueba en `perfiles` que esa persona tenga rol **admin**. Si no, responde
   «Solo el administrador puede crear usuarios» y no crea nada.
3. Valida el correo, el permiso y que la contraseña tenga 8 caracteres o más.
4. Crea el usuario con el correo ya confirmado (no hay que esperar ningún
   correo de verificación).
5. Le pone el permiso en `perfiles`.

Se despliega desde el panel de Supabase o con el MCP de Supabase. El código está
en el proyecto `oepsutldxratrvozpulq`, función `crear-usuario`.

Permisos válidos: `admin`, `planificacion`, `precosteo`, `prearmado`,
`precios`, `consulta`.
