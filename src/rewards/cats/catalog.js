export const CAT_TYPES=[
 ['Siamese','#e9d3b1','#57463f','points'],['Sphynx','#deb4ac','#b37c79','hairless'],['Calico','#f6e9d3','#d38245','calico'],['Orange tabby','#e8ae64','#a86735','stripes'],
 ['Silver tabby','#bec6cc','#626e7c','stripes'],['Tuxedo','#35404b','#f2eee5','tuxedo'],['British Shorthair','#8e9cae','#56647a','solid'],['Ragdoll','#f1e7d3','#817779','points'],
 ['Maine Coon','#b39a7c','#5e5144','longhair'],['Persian','#e7d9c8','#b19e8a','longhair'],['Bombay','#333746','#1b2131','solid'],['Russian Blue','#92a4b3','#5f758c','solid'],
 ['Bengal','#dbad62','#785234','spots'],['Snowshoe','#e2d3bb','#68564d','points'],['Turkish Van','#f4eddf','#b46d48','patches'],['Scottish Fold','#c2b6aa','#887d75','fold'],
 ['Norwegian Forest','#b9ab97','#706252','longhair'],['Birman','#e4dccb','#796357','points'],['Abyssinian','#bc7e48','#765237','solid'],['Devon Rex','#d7c4ad','#9b8977','hairless'],
 ['Dilute calico','#e5e0d7','#a6a9b2','calico'],['Chocolate tabby','#9f7860','#624936','stripes'],['White floof','#fff7e5','#cec4b4','longhair'],['Torbie','#b88a65','#625444','calico'],
 ['Cream tabby','#efcf99','#c69a66','stripes'],['Black and white','#f1e8d9','#343944','patches'],['Lilac point','#e9dfdb','#a695a2','points'],['Egyptian Mau','#bcb5a2','#716d61','spots'],
]
export const catType=index=>CAT_TYPES[((Number(index)||0)%CAT_TYPES.length+CAT_TYPES.length)%CAT_TYPES.length]
export const careUnlocked=(points,target)=>[.25,.5,.75,1].map(f=>Number(points)>=Number(target)*f)
