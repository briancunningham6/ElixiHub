{application,joken,
             [{modules,['Elixir.Joken','Elixir.Joken.Claim',
                        'Elixir.Joken.Config','Elixir.Joken.CurrentTime',
                        'Elixir.Joken.CurrentTime.OS','Elixir.Joken.Error',
                        'Elixir.Joken.Hooks',
                        'Elixir.Joken.Hooks.RequiredClaims',
                        'Elixir.Joken.Signer']},
              {optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger,crypto,jose]},
              {description,"JWT (JSON Web Token) library for Elixir.\n"},
              {registered,[]},
              {vsn,"2.6.2"}]}.
