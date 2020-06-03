Rails.application.routes.draw do
  resources :posts
  match '/view/:id', to: 'posts#view', via: 'get', as: 'view'
  match '/publish/:id', to: 'posts#publish', via: 'get', as: 'publish'  
  match '/shot/:id', to: 'posts#shot', via: 'get', as: 'shot'
  root 'posts#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
